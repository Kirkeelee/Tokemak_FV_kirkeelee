// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Address } from "openzeppelin-contracts/utils/Address.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { IPoolAdapter } from "src/interfaces/destinations/IPoolAdapter.sol";
import { ICryptoSwapPool, IPool } from "src/interfaces/external/curve/ICryptoSwapPool.sol";
import { IWETH9 } from "src/interfaces/utils/IWETH9.sol";
import { LibAdapter } from "src/libs/LibAdapter.sol";
import { Errors } from "src/utils/Errors.sol";

//slither-disable-start similar-names
library CurveV2FactoryCryptoAdapter {
    event DeployLiquidity(
        uint256[] amountsDeposited,
        address[] tokens,
        // 0 - lpMintAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address poolAddress
    );

    event WithdrawLiquidity(
        uint256[] amountsWithdrawn,
        address[] tokens,
        // 0 - lpBurnAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address poolAddress
    );

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minLpMintAmount,
        address poolAddress,
        address lpTokenAddress,
        IWETH9 weth,
        bool useEth
    ) public {
        _validateAmounts(amounts);
        Errors.verifyNotZero(minLpMintAmount, "minLpMintAmount");
        Errors.verifyNotZero(poolAddress, "poolAddress");
        Errors.verifyNotZero(lpTokenAddress, "lpTokenAddress");
        Errors.verifyNotZero(address(weth), "weth");

        uint256 nTokens = amounts.length;
        address[] memory tokens = new address[](nTokens);
        uint256[] memory coinsBalancesBefore = new uint256[](nTokens);
        for (uint256 i = 0; i < nTokens; ++i) {
            uint256 amount = amounts[i];
            address coin = ICryptoSwapPool(poolAddress).coins(i);
            tokens[i] = coin;
            if (amount > 0 && coin != LibAdapter.CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
                LibAdapter._approve(IERC20(coin), poolAddress, amount);
            }
            coinsBalancesBefore[i] = coin == LibAdapter.CURVE_REGISTRY_ETH_ADDRESS_POINTER
                ? address(this).balance
                : IERC20(coin).balanceOf(address(this));
        }

        uint256 deployed = _runDeposit(amounts, minLpMintAmount, poolAddress, useEth);

        IERC20 lpToken = IERC20(lpTokenAddress);

        _updateWethAddress(tokens, address(weth));

        emit DeployLiquidity(
            _compareCoinsBalances(coinsBalancesBefore, _getCoinsBalances(tokens, weth, useEth), amounts, true),
            tokens,
            [deployed, lpToken.balanceOf(address(this)), lpToken.totalSupply()],
            poolAddress
        );
    }

    function removeLiquidity(
        uint256[] memory amounts,
        uint256 maxLpBurnAmount,
        address poolAddress,
        address lpTokenAddress,
        IWETH9 weth
    ) public returns (address[] memory tokens, uint256[] memory actualAmounts) {
        if (amounts.length > 4) {
            revert Errors.InvalidParam("amounts");
        }
        Errors.verifyNotZero(maxLpBurnAmount, "maxLpBurnAmount");
        Errors.verifyNotZero(poolAddress, "poolAddress");
        Errors.verifyNotZero(lpTokenAddress, "lpTokenAddress");
        Errors.verifyNotZero(address(weth), "weth");

        uint256[] memory coinsBalancesBefore = new uint256[](amounts.length);
        tokens = new address[](amounts.length);
        uint256 ethIndex = 999;
        for (uint256 i = 0; i < amounts.length; ++i) {
            address coin = IPool(poolAddress).coins(i);
            tokens[i] = coin;

            if (coin == LibAdapter.CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
                coinsBalancesBefore[i] = address(this).balance;
                ethIndex = i;
            } else {
                tokens[i] = coin;
                coinsBalancesBefore[i] = IERC20(coin).balanceOf(address(this));
            }
        }
        uint256 lpTokenBalanceBefore = IERC20(lpTokenAddress).balanceOf(address(this));

        _runWithdrawal(poolAddress, amounts, maxLpBurnAmount);

        uint256 lpTokenBalanceAfter = IERC20(lpTokenAddress).balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceBefore - lpTokenBalanceAfter;
        if (lpTokenAmount > maxLpBurnAmount) {
            revert LibAdapter.LpTokenAmountMismatch();
        }
        actualAmounts = _compareCoinsBalances(
            coinsBalancesBefore, _getCoinsBalances(tokens, weth, ethIndex != 999 ? true : false), amounts, false
        );

        if (ethIndex != 999) {
            // Wrapping up received ETH as system operates with WETH
            weth.deposit{ value: actualAmounts[ethIndex] }();
        }

        _updateWethAddress(tokens, address(weth));

        emit WithdrawLiquidity(
            actualAmounts,
            tokens,
            [lpTokenAmount, lpTokenBalanceAfter, IERC20(lpTokenAddress).totalSupply()],
            poolAddress
        );
    }

    /// @notice Withdraw liquidity from Curve pool
    /// @dev Calls to external contract
    /// @dev We trust sender to send a true Curve poolAddress.
    ///      If it's not the case it will fail in the remove_liquidity_one_coin part
    /// @param poolAddress Curve pool address
    /// @param lpBurnAmount Amount of LP tokens to burn in the withdrawal
    /// @param coinIndex Index value of the coin to withdraw
    /// @param minAmount Minimum amount of coin to receive
    /// @return coinAmount Actual amount of the withdrawn token
    /// @return coin Address of the withdrawn token
    function removeLiquidityOneCoin(
        address poolAddress,
        uint256 lpBurnAmount,
        uint256 coinIndex,
        uint256 minAmount,
        IWETH9 weth
    ) public returns (uint256 coinAmount, address coin) {
        // We don't check for a minAmount == 0 as that is a valid scenario on
        // withdrawals where the user accounts for slippage at the router
        Errors.verifyNotZero(poolAddress, "poolAddress");
        Errors.verifyNotZero(lpBurnAmount, "lpBurnAmount");
        Errors.verifyNotZero(address(weth), "weth");

        // TODO: Test this, not sure this is working

        uint256 coinBalanceBefore;
        coin = ICryptoSwapPool(poolAddress).coins(coinIndex);

        if (coin == LibAdapter.CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
            coinBalanceBefore = address(this).balance;
        } else {
            coinBalanceBefore = IERC20(coin).balanceOf(address(this));
        }

        // In Curve V2 Factory Pools LP token address = pool address
        uint256 lpTokenBalanceBefore = IERC20(poolAddress).balanceOf(address(this));

        ICryptoSwapPool(poolAddress).remove_liquidity_one_coin(lpBurnAmount, coinIndex, minAmount);

        uint256 lpTokenBalanceAfter = IERC20(poolAddress).balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceBefore - lpTokenBalanceAfter;
        if (lpTokenAmount != lpBurnAmount) {
            revert LibAdapter.LpTokenAmountMismatch();
        }
        coinAmount = _getCoinAmount(coin, coinBalanceBefore);

        if (coinAmount < minAmount) revert LibAdapter.InvalidBalanceChange();

        if (coin == LibAdapter.CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
            // Wrapping up received ETH as system operates with WETH
            weth.deposit{ value: coinAmount }();
            coin = address(weth);
        }

        _emitWithdraw(coinAmount, coin, [lpTokenAmount, lpTokenBalanceAfter], poolAddress);
    }

    /**
     * @dev This is a helper function to replace Curve's Registry pointer
     * to ETH with WETH address to be compatible with the rest of the system
     */
    function _updateWethAddress(address[] memory tokens, address weth) private pure {
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (tokens[i] == LibAdapter.CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
                tokens[i] = weth;
            }
        }
    }

    /**
     * @dev This is a helper function to avoid stack-too-deep-errors
     */
    function _emitWithdraw(uint256 coinAmount, address coin, uint256[2] memory lpAmounts, address pool) private {
        emit WithdrawLiquidity(
            _toDynamicArray(coinAmount),
            _toDynamicArray(coin),
            [lpAmounts[0], lpAmounts[1], IERC20(pool).totalSupply()],
            pool
        );
    }

    /// @dev Validate to have at least one `amount` > 0 provided and `amounts` is <=4
    function _validateAmounts(uint256[] memory amounts) internal pure {
        uint256 nTokens = amounts.length;
        if (nTokens > 4) {
            revert Errors.InvalidParam("amounts");
        }
        bool nonZeroAmountPresent = false;
        for (uint256 i = 0; i < nTokens; ++i) {
            if (amounts[i] != 0) {
                nonZeroAmountPresent = true;
                break;
            }
        }
        if (!nonZeroAmountPresent) revert LibAdapter.NoNonZeroAmountProvided();
    }

    /// @dev Gets balances of pool's ERC-20 tokens or ETH
    function _getCoinsBalances(
        address[] memory tokens,
        IWETH9 weth,
        bool useEth
    ) private view returns (uint256[] memory coinsBalances) {
        uint256 nTokens = tokens.length;
        coinsBalances = new uint256[](nTokens);

        for (uint256 i = 0; i < nTokens; ++i) {
            address coin = tokens[i];
            if (coin == LibAdapter.CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
                coinsBalances[i] = useEth ? address(this).balance : weth.balanceOf(address(this));
            } else {
                coinsBalances[i] = IERC20(coin).balanceOf(address(this));
            }
        }
    }

    /// @dev Calculate the amount of coin received after one-coin-withdrawal
    function _getCoinAmount(address coin, uint256 coinBalanceBefore) private view returns (uint256 coinAmount) {
        uint256 coinBalanceAfter;
        if (coin == LibAdapter.CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
            coinBalanceAfter = address(this).balance;
        } else {
            coinBalanceAfter = IERC20(coin).balanceOf(address(this));
        }
        coinAmount = coinBalanceAfter - coinBalanceBefore;
    }

    /// @dev Validate to have a valid balance change
    function _compareCoinsBalances(
        uint256[] memory balancesBefore,
        uint256[] memory balancesAfter,
        uint256[] memory amounts,
        bool isLiqDeployment
    ) private pure returns (uint256[] memory balanceChange) {
        uint256 nTokens = amounts.length;
        balanceChange = new uint256[](nTokens);

        for (uint256 i = 0; i < nTokens; ++i) {
            uint256 balanceDiff =
                isLiqDeployment ? balancesBefore[i] - balancesAfter[i] : balancesAfter[i] - balancesBefore[i];

            if (balanceDiff < amounts[i]) {
                revert LibAdapter.InvalidBalanceChange();
            }
            balanceChange[i] = balanceDiff;
        }
    }

    function _runDeposit(
        uint256[] memory amounts,
        uint256 minLpMintAmount,
        address poolAddress,
        bool useEth
    ) private returns (uint256 deployed) {
        uint256 nTokens = amounts.length;
        ICryptoSwapPool pool = ICryptoSwapPool(poolAddress);
        if (useEth) {
            // slither-disable-start arbitrary-send-eth
            if (nTokens == 2) {
                uint256[2] memory staticParamArray = [amounts[0], amounts[1]];
                deployed = pool.add_liquidity{ value: amounts[0] }(staticParamArray, minLpMintAmount);
            } else if (nTokens == 3) {
                uint256[3] memory staticParamArray = [amounts[0], amounts[1], amounts[2]];
                deployed = pool.add_liquidity{ value: amounts[0] }(staticParamArray, minLpMintAmount);
            } else if (nTokens == 4) {
                uint256[4] memory staticParamArray = [amounts[0], amounts[1], amounts[2], amounts[3]];
                deployed = pool.add_liquidity{ value: amounts[0] }(staticParamArray, minLpMintAmount);
            }
            // slither-disable-end arbitrary-send-eth
        } else {
            if (nTokens == 2) {
                uint256[2] memory staticParamArray = [amounts[0], amounts[1]];
                deployed = pool.add_liquidity(staticParamArray, minLpMintAmount);
            } else if (nTokens == 3) {
                uint256[3] memory staticParamArray = [amounts[0], amounts[1], amounts[2]];
                deployed = pool.add_liquidity(staticParamArray, minLpMintAmount);
            } else if (nTokens == 4) {
                uint256[4] memory staticParamArray = [amounts[0], amounts[1], amounts[2], amounts[3]];
                deployed = pool.add_liquidity(staticParamArray, minLpMintAmount);
            }
        }
        if (deployed < minLpMintAmount) {
            revert LibAdapter.MinLpAmountNotReached();
        }
    }

    function _runWithdrawal(address poolAddress, uint256[] memory amounts, uint256 maxLpBurnAmount) private {
        uint256 nTokens = amounts.length;
        ICryptoSwapPool pool = ICryptoSwapPool(poolAddress);
        if (nTokens == 2) {
            uint256[2] memory staticParamArray = [amounts[0], amounts[1]];
            pool.remove_liquidity(maxLpBurnAmount, staticParamArray);
        } else if (nTokens == 3) {
            uint256[3] memory staticParamArray = [amounts[0], amounts[1], amounts[2]];
            pool.remove_liquidity(maxLpBurnAmount, staticParamArray);
        } else if (nTokens == 4) {
            uint256[4] memory staticParamArray = [amounts[0], amounts[1], amounts[2], amounts[3]];
            pool.remove_liquidity(maxLpBurnAmount, staticParamArray);
        }
    }

    function _toDynamicArray(uint256 value) private pure returns (uint256[] memory dynamicArray) {
        dynamicArray = new uint256[](1);
        dynamicArray[0] = value;
    }

    function _toDynamicArray(address value) private pure returns (address[] memory dynamicArray) {
        dynamicArray = new address[](1);
        dynamicArray[0] = value;
    }
    //slither-disable-end similar-names
}
