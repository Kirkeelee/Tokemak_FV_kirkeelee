// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Initializable } from "openzeppelin-contracts/proxy/utils/Initializable.sol";

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { Stats } from "src/stats/Stats.sol";
import { BaseStatsCalculator } from "src/stats/calculators/base/BaseStatsCalculator.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";

contract ProxyLSTCalculator is BaseStatsCalculator, Initializable {
    IStatsCalculator public statsCalculator;
    address public lstTokenAddress;
    bytes32 private _aprId;

    struct InitData {
        address lstTokenAddress;
        address statsCalculator;
    }

    constructor(ISystemRegistry _systemRegistry) BaseStatsCalculator(_systemRegistry) { }

    /// @inheritdoc IStatsCalculator
    function initialize(bytes32[] calldata, bytes calldata initData) external override initializer {
        InitData memory decodedInitData = abi.decode(initData, (InitData));
        lstTokenAddress = decodedInitData.lstTokenAddress;
        statsCalculator = IStatsCalculator(decodedInitData.statsCalculator);
        _aprId = keccak256(abi.encode("lst", lstTokenAddress));
    }

    /// @inheritdoc IStatsCalculator
    function getAddressId() external view returns (address) {
        return lstTokenAddress;
    }

    /// @inheritdoc IStatsCalculator
    function getAprId() external view returns (bytes32) {
        return _aprId;
    }

    function _snapshot() internal pure override {
        revert NoSnapshotTaken();
    }

    function shouldSnapshot() external pure returns (bool takeSnapshot) {
        return false;
    }

    function current() external view override returns (Stats.CalculatedStats memory stats) {
        return statsCalculator.current();
    }
}
