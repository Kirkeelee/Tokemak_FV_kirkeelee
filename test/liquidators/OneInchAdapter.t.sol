// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { BaseSwapperAdapter } from "../../src/liquidators/BaseSwapperAdapter.sol";
import { ISwapper } from "../../src/interfaces/liquidators/ISwapper.sol";
import { ONE_INCH_MAINNET, PRANK_ADDRESS, CVX_MAINNET, WETH_MAINNET } from "../utils/Addresses.sol";
import { ERC20Utils } from "../utils/ERC20Utils.sol";

// solhint-disable func-name-mixedcase
contract OneInchAdapterTest is Test {
    using ERC20Utils for IERC20;

    BaseSwapperAdapter private adapter;

    function setUp() public {
        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_770_565);
        vm.selectFork(forkId);

        adapter = new BaseSwapperAdapter(ONE_INCH_MAINNET);
    }

    function test_Revert_IfBuyTokenAddressIsZeroAddress() public {
        vm.expectRevert(ISwapper.TokenAddressZero.selector);
        adapter.swap(PRANK_ADDRESS, 0, address(0), 0, new bytes(0));
    }

    function test_Revert_IfSellTokenAddressIsZeroAddress() public {
        vm.expectRevert(ISwapper.TokenAddressZero.selector);
        adapter.swap(address(0), 0, PRANK_ADDRESS, 0, new bytes(0));
    }

    function test_Revert_IfSellAmountIsZero() public {
        vm.expectRevert(ISwapper.InsufficientSellAmount.selector);
        adapter.swap(PRANK_ADDRESS, 0, PRANK_ADDRESS, 1, new bytes(0));
    }

    function test_Revert_IfBuyAmountIsZero() public {
        vm.expectRevert(ISwapper.InsufficientBuyAmount.selector);
        adapter.swap(PRANK_ADDRESS, 1, PRANK_ADDRESS, 0, new bytes(0));
    }

    function test_swap() public {
        // solhint-disable max-line-length
        bytes memory data =
            hex"12aa3caf0000000000000000000000007122db0ebe4eb9b434a9f2ffe6760bc03bfbd0e00000000000000000000000004e3fbd56cd56c3e72c1403e103b45db9da5b9d2b000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000007122db0ebe4eb9b434a9f2ffe6760bc03bfbd0e00000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000000000000000000000000000000000000000001954af4d2d99874cf00000000000000000000000000000000000000000000000001810765f6459f850f6000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005210000000000000000000000000000000000000000000005030004d500048b00a0c9e75c480000000000000000310100000000000000000000000000000000000000000000000000045d00038d00a0860a32ec000000000000000000000000000000000000000000000081b196060830c938000003645500080bf510fcbf18b91105470639e95610229377124e3fbd56cd56c3e72c1403e103b45db9da5b9d2b95e6f48254609a6ee006f7d493c8e5fb97094cef0024b4be83d50000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a000000000000000000000000056178a0d5f301baf6cf3e1cd53d9863437345bf90000000000000000000000007122db0ebe4eb9b434a9f2ffe6760bc03bfbd0e000000000000000000000000055662e225a3376759c24331a9aed764f8f0c9fbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007c8db4fcf9cef924000000000000000000000000000000000000000000000081b196060830c93800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064061df901ffffffffffffffffffffffffffffffffffffff13ca539364061d8100000026000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000024f47261b0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024f47261b00000000000000000000000004e3fbd56cd56c3e72c1403e103b45db9da5b9d2b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000421c54f7bbfd635d9f1524b43ef0533c3506ec63cc99564b75e472849b6b8677c3012e618012e5b09bd6cb8f3f6787123ac00a0cd891d46ec8231b2b41de248d9c04030000000000000000000000000000000000000000000000000000000000005120b576491f1e6e5e62f1d8f26062ee822b40b0e0d44e3fbd56cd56c3e72c1403e103b45db9da5b9d2b0044394747c50000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000179520b448791495d8000000000000000000000000000000000000000000000000000000000000000000a0f2fa6b66c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000184eb0750adc2bf4b10000000000000000000b505133d2d88380a06c4eca27c02aaa39b223fe8d0a0e5c4f27ead9083c756cc21111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000000000000000000000000000000000cfee7c08";

        address whale = 0xcba0074a77A3aD623A80492Bb1D8d932C62a8bab;
        vm.startPrank(whale);
        IERC20(CVX_MAINNET).transferAll(whale, address(adapter));
        vm.stopPrank();

        uint256 balanceBefore = IERC20(WETH_MAINNET).balanceOf(address(adapter));

        adapter.swap(CVX_MAINNET, 119_621_320_376_600_000_000_000, WETH_MAINNET, 356_292_255_653_182_345_276, data);

        uint256 balanceAfter = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 balanceDiff = balanceAfter - balanceBefore;

        assertTrue(balanceDiff >= 356_292_255_653_182_345_276);
    }
}