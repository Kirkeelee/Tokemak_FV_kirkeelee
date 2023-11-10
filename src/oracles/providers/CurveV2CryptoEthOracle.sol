// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { SecurityBase } from "src/security/SecurityBase.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { ISpotPriceOracle } from "src/interfaces/oracles/ISpotPriceOracle.sol";
import { SystemComponent } from "src/SystemComponent.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ICurveResolver } from "src/interfaces/utils/ICurveResolver.sol";
import { Errors } from "src/utils/Errors.sol";
import { ICryptoSwapPool } from "src/interfaces/external/curve/ICryptoSwapPool.sol";
import { ICurveV2Swap } from "src/interfaces/external/curve/ICurveV2Swap.sol";

contract CurveV2CryptoEthOracle is SystemComponent, SecurityBase, IPriceOracle, ISpotPriceOracle {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ICurveResolver public immutable curveResolver;
    uint256 public constant FEE_PRECISION = 1e10;

    /**
     * @notice Struct for neccessary information for single Curve pool.
     * @param pool The address of the curve pool.
     * @param checkReentrancy uint8 representing a boolean.  0 for false, 1 for true.
     * @param tokentoPrice Address of the token being priced in the Curve pool.
     * @param tokenFromPrice Addre of the token being used to price the token in the Curve pool.
     */
    struct PoolData {
        address pool;
        uint8 checkReentrancy;
        address tokenToPrice;
        address tokenFromPrice;
    }

    /**
     * @notice Emitted when token Curve pool is registered.
     * @param lpToken Lp token that has been registered.
     */
    event TokenRegistered(address lpToken);

    /**
     * @notice Emitted when a Curve pool registration is removed.
     * @param lpToken Lp token that has been unregistered.
     */
    event TokenUnregistered(address lpToken);

    /**
     * @notice Thrown when pool returned is not a v2 curve pool.
     * @param curvePool Address of the pool that was attempted to be registered.
     */
    error NotCryptoPool(address curvePool);

    /**
     * @notice Thrown when wrong lp token is returned from CurveResolver.sol.
     * @param providedLP Address of lp token provided in function call.
     * @param queriedLP Address of lp tokens returned from resolver.
     */
    error ResolverMismatch(address providedLP, address queriedLP);

    /**
     * @notice Thrown when a Curve V2 Lp token is already registered.
     * @param curveLpToken The address of the token attempted to be deployed.
     */
    error AlreadyRegistered(address curveLpToken);

    /**
     * @notice Thrown when lp token is not registered.
     * @param curveLpToken Address of token expected to be registered.
     */
    error NotRegistered(address curveLpToken);

    /**
     * @notice Thrown when a pool with an invalid number of tokens is attempted to be registered.
     * @param numTokens The number of tokens in the pool attempted to be registered.
     */
    error InvalidNumTokens(uint256 numTokens);

    /**
     * @notice Thrown when y and z values do not converge during square root calculation.
     */
    error SqrtError();

    /// @notice Reverse mapping of LP token to pool info.
    mapping(address => PoolData) public lpTokenToPool;

    /**
     * @param _systemRegistry Instance of system registry for this version of the system.
     * @param _curveResolver Instance of Curve Resolver.
     */
    constructor(
        ISystemRegistry _systemRegistry,
        ICurveResolver _curveResolver
    ) SystemComponent(_systemRegistry) SecurityBase(address(_systemRegistry.accessController())) {
        Errors.verifyNotZero(address(_systemRegistry.rootPriceOracle()), "rootPriceOracle");
        Errors.verifyNotZero(address(_curveResolver), "_curveResolver");

        curveResolver = _curveResolver;
    }

    /**
     * @notice Allows owner of system to register a pool.
     * @dev While the reentrancy check implemented in this contact can technically be used with any token,
     *      it does not make sense to check for reentrancy unless the pool contains ETH, WETH, ERC-677, ERC-777 tokens,
     *      as the known Curve reentrancy vulnerability only works when the caller recieves these tokens.
     *      Therefore, reentrancy checks should only be set to `1` when these tokens are present.  Otherwise we
     *      waste gas claiming admin fees for Curve.
     * @param curvePool Address of CurveV2 pool.
     * @param curveLpToken Address of LP token associated with v2 pool.
     * @param checkReentrancy Whether to check read-only reentrancy on pool.  Set to true for pools containing
     *      ETH or WETH.
     */
    function registerPool(address curvePool, address curveLpToken, bool checkReentrancy) external onlyOwner {
        Errors.verifyNotZero(curvePool, "curvePool");
        Errors.verifyNotZero(curveLpToken, "curveLpToken");
        if (lpTokenToPool[curveLpToken].pool != address(0)) revert AlreadyRegistered(curveLpToken);

        (address[8] memory tokens, uint256 numTokens, address lpToken, bool isStableSwap) =
            curveResolver.resolveWithLpToken(curvePool);

        // Only two token pools compatible with this contract.
        if (numTokens != 2) revert InvalidNumTokens(numTokens);
        if (isStableSwap) revert NotCryptoPool(curvePool);
        if (lpToken != curveLpToken) revert ResolverMismatch(curveLpToken, lpToken);

        /**
         * Curve V2 pools always price second token in `coins` array in first token in `coins` array.  This means that
         *    if `coins[0]` is Weth, and `coins[1]` is rEth, the price will be rEth as base and weth as quote.  Hence
         *    to get lp price we will always want to use the second token in the array, priced in eth.
         */
        lpTokenToPool[lpToken] = PoolData({
            pool: curvePool,
            checkReentrancy: checkReentrancy ? 1 : 0,
            tokenToPrice: tokens[1],
            tokenFromPrice: tokens[0]
        });

        emit TokenRegistered(lpToken);
    }

    /**
     * @notice Allows owner of system to unregister curve pool.
     * @param curveLpToken Address of CurveV2 lp token to unregister.
     */
    function unregister(address curveLpToken) external onlyOwner {
        Errors.verifyNotZero(curveLpToken, "curveLpToken");

        if (lpTokenToPool[curveLpToken].pool == address(0)) revert NotRegistered(curveLpToken);

        delete lpTokenToPool[curveLpToken];

        emit TokenUnregistered(curveLpToken);
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address token) external returns (uint256 price) {
        Errors.verifyNotZero(token, "token");

        PoolData memory poolInfo = lpTokenToPool[token];
        if (poolInfo.pool == address(0)) revert NotRegistered(token);

        ICryptoSwapPool cryptoPool = ICryptoSwapPool(poolInfo.pool);

        // Checking for read only reentrancy scenario.
        if (poolInfo.checkReentrancy == 1) {
            // This will fail in a reentrancy situation.
            cryptoPool.claim_admin_fees();
        }

        uint256 virtualPrice = cryptoPool.get_virtual_price();
        uint256 assetPrice = systemRegistry.rootPriceOracle().getPriceInEth(poolInfo.tokenToPrice);

        return (2 * virtualPrice * sqrt(assetPrice)) / 10 ** 18;
    }

    // solhint-disable max-line-length
    // Adapted from CurveV2 pools, see here:
    // https://github.com/curvefi/curve-crypto-contract/blob/d7d04cd9ae038970e40be850df99de8c1ff7241b/contracts/two/CurveCryptoSwap2.vy#L1330
    function sqrt(uint256 x) private pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 10 ** 18) / 2;
        uint256 y = x;

        for (uint256 i = 0; i < 256;) {
            if (z == y) {
                return y;
            }
            y = z;
            z = (x * 10 ** 18 / z + z) / 2;

            unchecked {
                ++i;
            }
        }
        revert SqrtError();
    }

    /// @inheritdoc ISpotPriceOracle
    function getSpotPrice(
        address token,
        address pool,
        address requestedQuoteToken
    ) public view returns (uint256 price, address actualQuoteToken) {
        address lpToken = curveResolver.getLpToken(pool);
        int256 tokenIndex = -1;
        int256 quoteTokenIndex = -1;
        // Find the token and quote token indices
        PoolData storage poolInfo = lpTokenToPool[lpToken];

        if (poolInfo.tokenToPrice == token) {
            tokenIndex = 1;
        } else if (poolInfo.tokenFromPrice == token) {
            tokenIndex = 0;
        } else {
            revert NotRegistered(lpToken);
        }
        if (poolInfo.tokenToPrice == requestedQuoteToken) {
            quoteTokenIndex = 1;
        } else if (poolInfo.tokenFromPrice == requestedQuoteToken) {
            quoteTokenIndex = 0;
        } else {
            // Selecting a different quote token if the requested one is not found.
            quoteTokenIndex = tokenIndex == 0 ? int256(1) : int256(0);
        }
        uint256 dy = ICurveV2Swap(pool).get_dy(uint256(tokenIndex), uint256(quoteTokenIndex), 1e18);

        /// @dev The fee is dynamically based on current balances; slight discrepancies post-calculation are acceptable
        /// for low-value swaps.
        uint256 fee = ICurveV2Swap(pool).fee();
        uint256 netDy = (dy * FEE_PRECISION) / (FEE_PRECISION - fee);

        address actualQuoteTokenAddress = ICurveV2Swap(pool).coins(uint256(quoteTokenIndex));
        return (netDy, actualQuoteTokenAddress);
    }
}
