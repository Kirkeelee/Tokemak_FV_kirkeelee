import "./erc20.spec";

use builtin rule sanity;

methods {
    function _.getPriceInEth(address token) external with (env e) => getPriceInEthCVL[token][e.block.timestamp] expect (uint256);
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
    function swapCostOffsetTightenThresholdInViolations() external returns (uint16) envfree;
    function swapCostOffsetMaxInDays() external returns (uint16) envfree;
    function swapCostOffsetMinInDays() external returns (uint16) envfree;
}


ghost uint256 getBptIndexCVL;

ghost mapping(address => mapping(uint256 => uint256)) getPriceInEthCVL;


ghost uint16 _swapCostOffsetPeriodGhost;

hook Sload uint16 defaultValue _swapCostOffsetPeriod STORAGE {
    require _swapCostOffsetPeriodGhost == defaultValue;
}

hook Sstore _swapCostOffsetPeriod uint16 defaultValue STORAGE {
    _swapCostOffsetPeriodGhost = defaultValue;
}



ghost uint8 violationCountGhost;

ghost uint8 violationCountOldGhost;


hook Sstore currentContract.violationTrackingState.violationCount uint8 defaultValue 
    (uint8 defaultValue_old) STORAGE {
    violationCountGhost = defaultValue;
    violationCountOldGhost = defaultValue_old;
}




// STATUS - verified
rule cantJumpTwoViolationsAtOnce(env e, method f) {
    uint16 numOfViolationsBefore;
    numOfViolationsBefore,_,_ = violationTrackingState();

    calldataarg args;
    f(e, args);

    uint16 numOfViolationsAfter;
    numOfViolationsAfter,_,_ = violationTrackingState();

    assert numOfViolationsAfter - numOfViolationsBefore <= 1;
}


// STATUS - in progress
// violation count >= swapCostOffsetTightenThresholdInViolations  && current rebalance is also a violation => offset should decrease
rule violationCountAffectsOffset(env e, method f) {
    uint16 offsetPeriodBefore = _swapCostOffsetPeriodGhost;

    calldataarg args;
    f(e, args);

    uint8 violationsAfter; 
    violationsAfter,_,_= violationTrackingState();

    uint16 offsetPeriodAfter = _swapCostOffsetPeriodGhost;

    assert (require_uint16(violationCountGhost) > swapCostOffsetTightenThresholdInViolations()
                || require_uint16(violationCountOldGhost) > swapCostOffsetTightenThresholdInViolations())
             => offsetPeriodBefore > offsetPeriodAfter;
}



// STATUS - in progress
// offset period should be between swapCostOffsetMaxInDays and swapCostOffsetMinInDays
invariant offsetIsInBetween()
    _swapCostOffsetPeriodGhost <= swapCostOffsetMaxInDays() && _swapCostOffsetPeriodGhost >= swapCostOffsetMinInDays();





