// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TODO peanut interface
interface IPeanutV4 {
    function makeDeposit(
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address _pubKey20
    ) external payable returns (uint256);
}

contract PeanutForwarder {
    constructor() {}

    // Fallback function must be declared as external.
    fallback() external payable {
        createLink();
    }

    // Receive is a variant of fallback that is triggered when msg.data is empty
    receive() external payable {
        createLink();
    }

    function abiPeanutEncode(
        uint256 amount,
        address pubKey20
    ) public pure returns (bytes memory) {
        return abi.encodePacked(address(0), uint8(0), amount, uint256(0), pubKey20);
    }

    function createLink() internal {
        // TODO update with peanut contract
        address peanutV4Address = address(0x1234);
        uint256 amount = 0; //address(uint160(bytes20(msg.data[0:20])));
        address pubKey20 = address(uint160(bytes20(msg.data[20:40])));

        IPeanutV4(peanutV4Address).makeDeposit(address(0), uint8(0), amount, uint256(0), pubKey20);
    }

}