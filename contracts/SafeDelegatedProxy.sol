// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//
// Imported code
//

// from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol
interface IERC721 {
    function ownerOf(uint256 _tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

// From code sample found
contract Enum {
    enum Operation {
        Call, DelegateCall
    }
}

interface Executor {
    /// @dev Allows a Module to execute a transaction.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(address to, uint256 value, bytes calldata data, Enum.Operation operation)
        external
        returns (bool success);
}

contract SafeDelegatedProxy {

    //
    // Buying logic
    //

    struct PurchaseNativeInfo {
        bool initiated;
        uint256 maxSpend;
        Executor gnosisSafeInstance;
    }

    struct Purchase721Info {
        bool initiated;
        uint256 maxPrice;
        Executor gnosisSafeInstance;
    }

    // For a given nft and index, specify the maximum amount that will be paid
    mapping(bytes32 => Purchase721Info) public allowances721;

    // For a given contract, specify the maximum amount that can be sent
    mapping(bytes32 => PurchaseNativeInfo) public allowancesNative;

    function generateBuyAllowanceKey(address owner, address nft, uint256 tokenId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, nft, tokenId));
    }

    function getMaxAmountToPayForNFT(address owner, address nft, uint256 tokenId) public view returns (uint256) {
        bytes32 key = generateBuyAllowanceKey(owner, nft, tokenId);
        return allowances721[key].maxPrice;
    }

    function getMaxContractAllowance(address owner, address contract) public view returns (uint256) {
        bytes32 key = generateBuyAllowanceKey(owner, contract, 0);
        return allowancesNative[key].maxSpend;
    }

    function setMaxAmountToPayForNFT(address owner, address nft, uint256 tokenId, uint256 amount, address spender) public {
        require(msg.sender == owner, "Only owner can set allowance");
        bytes32 key = generateBuyAllowanceKey(owner, nft, tokenId);
        allowances721[key] = Purchase721Info({initiated:false, maxPrice:amount, gnosisSafeInstance:Executor(spender)});
    }

    function setMaxContractAllowance(address owner, address contract, uint256 amount, address spender) public {
        require(msg.sender == owner, "Only owner can set allowance");
        bytes32 key = generateBuyAllowanceKey(owner, nft, 0);
        allowancesNative[key] = PurchaseNativeInfo({initiated:false, maxPrice:amount, gnosisSafeInstance:Executor(spender)});
    }

    function buyNFT(
        address owner,
        address nft,
        uint256 tokenId,
        uint256 amount,
        address payable seller) public {

        bytes32 key = generateBuyAllowanceKey(owner, nft, tokenId);
        require(amount <= allowances721[key].maxPrice, "Price less than expected");
        // Protect against re-entrancy
        require(!allowances721[key].initiated, "Already in progress");

        allowances721[key].initiated = true;

        // It's expected the receiver of the funds sends the NFT in the same transaction
        transferEtherFromGnosisSafe(
            Executor(owner),         // Safe SCW funds will be taken from
            nft,                                        // NFT being bought
            tokenId,                                    // ID of NFT being bought
            seller,                                     // Market destination where NFT will be sent from
            amount);                                    // Cost of NFT

        // Resulting in the NFT now belonging to the user
        require(IERC721(nft).ownerOf(tokenId) == address(this), "NFT not transferred");

        delete allowances721[key];

        // Now this contract owns the NFT, forward it to the real owner
        IERC721(nft).transferFrom(address(this), owner, tokenId);
    }

    function createPeanutLink(
        address owner,
        address peanutForwarderContract,
        uint256 amount,
        address pubKey20) public {

        bytes32 key = generateBuyAllowanceKey(owner, peanutContract, 0);
        require(amount <= allowancesNative[key].maxSpend, "Price less than expected");
        // Protect against re-entrancy
        require(!allowancesNative[key].initiated, "Already in progress");

        allowancesNative[key].initiated = true;

        // Encode call to peanut forwarder
        bytes memory data = abi.encodePacked(
            amount,
            pubKey20);     // claiming public key

        Enum.Operation op = Enum.Operation.Call;
        (bool success) = payer.execTransactionFromModule(
            peanutForwarderContract,
            amount,
            data,
            op
        );

        require(success, "Transfer from Gnosis Safe failed");

        delete allowancesNative[key];
    }

    function transferEtherFromGnosisSafe(
        Executor payer,
        address nft,
        uint256 tokenId,
        address payable _to,
        uint256 _amount) public {

        bytes memory data = abi.encodePacked(address(this), nft, tokenId);

        Enum.Operation op = Enum.Operation.Call;
        (bool success) = payer.execTransactionFromModule(
            _to,
            _amount,
            data,
            op
        );

        require(success, "Transfer from Gnosis Safe failed");
    }

    //
    // Selling logic
    //

    struct SellAllowanceInfo {
        bool canBeTransferred;

        bool canBeSold;
        uint256 minPrice;
    }

    mapping(bytes32 => SellAllowanceInfo) public sellingallowances721;

    function generateSellAllowanceKey(address owner, address nft, uint256 tokenId, address spender) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, nft, tokenId, spender));
    }

    function canSellNFT(address owner, address nft, uint256 tokenId, address spender) external view returns (bool, uint256) {
        bytes32 key = generateSellAllowanceKey(owner, nft, tokenId, spender);
        return (sellingallowances721[key].canBeSold, sellingallowances721[key].minPrice);
    }

    function canTransferNFT(address owner, address nft, uint256 tokenId, address spender) external view returns (bool) {
        bytes32 key = generateSellAllowanceKey(owner, nft, tokenId, spender);
        return sellingallowances721[key].canBeTransferred;
    }

    function sellNFT(address owner, address nft, uint256 tokenId, address destination) external payable {
        bytes32 key = generateSellAllowanceKey(owner, nft, tokenId, destination);

        require(sellingallowances721[key].canBeSold, "Not sellable");
        require(msg.value >= sellingallowances721[key].minPrice, "Insufficient payment");
        // Implicitly the caller is allowed to spend
        
        payable(owner).transfer(sellingallowances721[key].minPrice);

        IERC721 nftContract = IERC721(nft);
        nftContract.transferFrom(owner, destination, tokenId);

        delete sellingallowances721[key];
    }

    function transferNFT(address owner, address nft, uint256 tokenId, address destination) external {
        bytes32 key = generateSellAllowanceKey(owner, nft, tokenId, destination);

        require(sellingallowances721[key].canBeTransferred, "Not transferrable");
        // Implicitly the caller is allowed to send
        IERC721 nftContract = IERC721(nft);
        nftContract.transferFrom(owner, destination, tokenId);

        delete sellingallowances721[key];
    }

    function setSellAllowance(
        address nft,
        uint256 tokenId,
        bool canBeSold,
        uint256 minPrice,
        address destination,
        bool canBeTransferred
    ) external {
        if (minPrice > 0) {
            require(canBeSold, "Price requires selling permission");
        }

        address owner = msg.sender;
        bytes32 key = generateSellAllowanceKey(owner, nft, tokenId, destination);

        sellingallowances721[key] = SellAllowanceInfo({
            canBeSold: canBeSold,
            minPrice: minPrice,
            canBeTransferred: canBeTransferred
        });
    }

    // from import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}