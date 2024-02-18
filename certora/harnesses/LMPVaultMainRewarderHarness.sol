// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "../../src/rewarders/LMPVaultMainRewarder.sol";

contract LMPVaultMainRewarderHarness is LMPVaultMainRewarder {
    constructor(
        ISystemRegistry _systemRegistry,
        address _stakeTracker,
        address _rewardToken,
        uint256 _newRewardRatio,
        uint256 _durationInBlock,
        bool _allowExtraReward
    )
        LMPVaultMainRewarder(
            _systemRegistry,
            _stakeTracker,
            _rewardToken,
            _newRewardRatio,
            _durationInBlock,
            _allowExtraReward
        )
    { }

    function updateReward(address account) public {
        _updateReward(account);
    }
}