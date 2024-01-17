import "./erc20.spec";

use builtin rule sanity;

methods {
    function _.getPriceInEth(address token) external => getPriceInEthCVL[token] expect (uint256);
    function _.getStats() external => DISPATCHER(true);
    function _.getValidatedSpotPrice() external => DISPATCHER(true);
    function _.isShutdown() external => DISPATCHER(true);
    function _.getPool() external => DISPATCHER(true);
    function _.getPriceOrZero(address, uint40) external => DISPATCHER(true);
    function _.underlying() external => DISPATCHER(true);
    function _.underlyingTokens() external => DISPATCHER(true);
    function _.debtValue(uint256) external => DISPATCHER(true);
    function _.getSpotPriceInEth(address, address) external => DISPATCHER(true);

    function _.getBptIndex() external => getBptIndexCVL expect (uint256);

    function violationTrackingState() external returns (uint8, uint8, uint16) envfree;
}


ghost uint256 getBptIndexCVL;

ghost mapping(address => uint256) getPriceInEthCVL;



rule cantJumpTwoViolationsAtOnce(env e, method f) {
    uint16 numOfViolationsBefore;
    numOfViolationsBefore,_,_ = violationTrackingState();

    calldataarg args;
    f(e, args);

    uint16 numOfViolationsAfter;
    numOfViolationsAfter,_,_ = violationTrackingState();

    assert numOfViolationsAfter - numOfViolationsBefore <= 1;
}


