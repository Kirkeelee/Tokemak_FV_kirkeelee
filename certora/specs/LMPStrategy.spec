import "./erc20.spec";

use builtin rule sanity;

methods {
    function _.getPriceInEth(address) external => DISPATCHER(true);
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
}


ghost uint256 getBptIndexCVL;
