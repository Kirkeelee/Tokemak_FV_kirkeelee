import "erc20.spec";

using ExtraRewarder as extraRewarder;
using ExtraRewarder1 as extraRewarder1;

methods {
    function _.stake(address,uint256) external => DISPATCHER(true);
    function _.getReward(address) external => DISPATCHER(true);
    function _.withdraw(address,uint256) external => DISPATCHER(true);

    function _.stake(uint256,uint256,address) external => DISPATCHER(true);
    function _.isStakeableAmount(uint256) external => DISPATCHER(true);

    function _.toke() external => DISPATCHER(true);
    function _.accToke() external => DISPATCHER(true);

    function _.hasRole(bytes32 role, address user) external => hasRoleCVL(role, user) expect bool;

    function updateReward(address) external envfree;
    function earned(address) external returns(uint256) envfree;

    function getExtraRewarder(uint256 index) external returns(address) envfree;
    function rewardPerToken() external returns(uint256) envfree;
}

// use rule privilegedOperation;
use builtin rule sanity;

ghost mapping(bytes32 => mapping(address => bool)) rolesCVL;

function hasRoleCVL(bytes32 role, address user) returns bool {
    return rolesCVL[role][user];
}

function setup() {
    require getExtraRewarder(0) == extraRewarder;
    require getExtraRewarder(1) == extraRewarder1;
}

rule privilegedOperation(method f, address privileged)
{
    setup();
	env e1;
	calldataarg arg;
	require e1.msg.sender == privileged;

	storage initialStorage = lastStorage;
	f@withrevert(e1, arg); // privileged succeeds executing candidate privileged operation.
	bool firstSucceeded = !lastReverted;

	env e2;
	calldataarg arg2;
	require e2.msg.sender != privileged;
	f@withrevert(e2, arg2) at initialStorage; // unprivileged
	bool secondSucceeded = !lastReverted;

	assert  !(firstSucceeded && secondSucceeded), "${f.selector} can be called by both ${e1.msg.sender} and ${e2.msg.sender}, so it is not privileged";
}
// two specs: 
//   1 summary for updateReward (assume userRewardPerTokenPaid[account] = rewardPerTokenStored), high level rules will check that _updateReward is called at the right place
//   normal spec, used to prove properties about code when updateReward is called, these properties are assumed in the high level rules written in the summarized spec

rule updateReward(address account) {
    setup();
    require account != 0;
    require currentContract.rewardPerTokenStored > 0;
    // requireInvariant rewardPerTokenGTUsers(account);
    // requireInvariant rewardPerTokenNonzero(account);

    updateReward(account);

    assert currentContract.userRewardPerTokenPaid[account] == currentContract.rewardPerTokenStored;
    // assert earned(account) == currentContract.rewards[account];
}

invariant rewardPerTokenGTUsers(address account) 
    currentContract.rewardPerTokenStored >= currentContract.userRewardPerTokenPaid[account];

invariant rewardPerTokenNonzero(address account) 
    currentContract.rewardPerTokenStored == 0 => currentContract.userRewardPerTokenPaid[account] == 0;

invariant whyNot(address account)
    rewardPerToken() != currentContract.userRewardPerTokenPaid[account];