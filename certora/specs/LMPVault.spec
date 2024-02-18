import "complexity.spec";

methods {
    // accToke.isStakeableAmount(address)
    // accToke.stake(uint256,uint256,address)

    function _.stake(address,uint256) external => DISPATCHER(true);
    function _.getReward(address) external => DISPATCHER(true);
    function _.withdraw(address,uint256) external => DISPATCHER(true);
    
    function _.navOpsInProgress() external => DISPATCHER(true);
    function _.exitNavOperation() external => DISPATCHER(true);
    function _.enterNavOperation() external => DISPATCHER(true);

    // destinationRegistry.isRegistered(dAddress)

    function _.getReward(address, bool) external => DISPATCHER(true);

    function _.getRebalanceOutSummaryStats(IStrategy.RebalanceParams) external => DISPATCHER(true);
    function _.verifyRebalance(IStrategy.RebalanceParams,IStrategy.SummaryStats) external => DISPATCHER(true);
    
    function _.withdrawUnderlying(uint256, address) external => DISPATCHER(true);
    function _.depositUnderlying(uint256) external => DISPATCHER(true);

    function _.onFlashLoan(address,address,uint256,uint256,bytes) external => DISPATCHER(true);

    function _.rewarder() external => DISPATCHER(true);
    function _.debtValue(uint256) external => DISPATCHER(true);
    function _.withdrawBaseAsset(uint256, address) external => DISPATCHER(true); 
}

use rule privilegedOperation;
use rule sanity;