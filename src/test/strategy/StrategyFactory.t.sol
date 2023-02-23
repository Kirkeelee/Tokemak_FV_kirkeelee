// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "ds-test/test.sol";

import { HardCodedStrategy } from "../../strategy/HardCodedStrategy.sol";
import { StrategyFactory } from "../../strategy/StrategyFactory.sol";
import { Hevm } from "../interfaces/Hevm.sol";
import { PRANK_ADDRESS, HEVM_ADDRESS } from "../utils/Addresses.sol";

contract StrategyFactoryTest is DSTest {
    StrategyFactory private factory;
    address[] private destinations;
    Hevm private vm = Hevm(HEVM_ADDRESS);

    uint256 private constant MAX_DESTINATIONS = 16;

    function setUp() public {
        initDestinations(MAX_DESTINATIONS);
        factory = new StrategyFactory();
    }

    function testSetPercentages() public {
        address strategyAddress = factory.createStrategy(destinations);

        HardCodedStrategy strategy = HardCodedStrategy(strategyAddress);

        address[] memory result = strategy.getDestinations();
        for (uint256 i = 0; i < result.length; i++) {
            assertEq(result[i], destinations[i]);
        }
    }

    function initDestinations(uint256 count) private {
        destinations = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            destinations[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
        }
    }
}