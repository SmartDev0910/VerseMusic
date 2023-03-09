// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
// import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract VerseMusic is ERC1155Upgradeable, ReentrancyGuardUpgradeable {
    address public owner;

    bool public mintNFTPaused;
    bool public burnNFTPaused;

    uint256 private constant nftSeriesId = 1;
    uint256 private availableNFTsForMint; // counter for remaining nfts to be minted
    uint256 private availableNFTsForReward; // counter for nfts waiting for reward

    uint256 private totalRewardSeries;
    uint256 private currentRewardSeriesId;
    mapping(uint256 => uint256) private rewardSupplies; // reward series Id to reward supplies
    mapping(uint256 => string) private tokenURI; // reward series Id to reward token URI

    bytes32 private validKeysMerkleRoot;
    uint256 private currentMerkleRound;
    mapping(uint256 => mapping(string => bool)) private keyUsed;

    /* one PFP can mint a nft per each level in each series */
    /* the order of below mapping variable is : series Id ==> collection Id ==> token Id ==> level ==> minted flag */
    // mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(uint256 => bool)))) private alreadyMinted;

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root, string memory leaf) {
        require(
            MerkleProofUpgradeable.verify(
                merkleProof,
                root,
                keccak256(abi.encodePacked(leaf))
            ),
            "This key does not exist in list"
        );
        _;
    }

    function __ERC1155WithMetadata_init(string memory uri_)
        internal
        initializer
    {
        __ERC1155_init_unchained(uri_);
        owner = msg.sender;
        currentRewardSeriesId = 1;
    }

    function setValidKeysMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        validKeysMerkleRoot = merkleRoot;
        currentMerkleRound ++;
    }

    function pauseMintNFT(bool pause) external onlyOwner {
        mintNFTPaused = pause;
    }

    function pauseBurnNFT(bool pause) external onlyOwner {
        burnNFTPaused = pause;
    }

    function createNewNFTSupply(uint256 supply) external onlyOwner {
        availableNFTsForMint += supply;
        availableNFTsForReward += supply;
    }

    function createNewRewardSupply(uint256 supply, string memory _tokenUri) external onlyOwner {
        require(availableNFTsForReward >= supply, "exceeds available reward supply, please add more nft");

        availableNFTsForReward -= supply;
        totalRewardSeries ++;
        tokenURI[totalRewardSeries + nftSeriesId] = _tokenUri;
        rewardSupplies[totalRewardSeries + nftSeriesId] = supply;
    }

    // only game should be able to call this function
    function mintNFT(bytes32[] calldata merkleProof, string memory myKey) external payable isValidMerkleProof(merkleProof, validKeysMerkleRoot, myKey) nonReentrant {
        require(!mintNFTPaused, "nft minting is paused");
        require(!keyUsed[currentMerkleRound][myKey], "This key is already used");
        // require(!alreadyMinted[currentSeriesId][collectionId][tokenId][level], "already minted a nft in this level with this PFP for this series");
        require(availableNFTsForMint > 0, "all nfts are minted already");
        _mint(msg.sender, nftSeriesId, 1, "0x00");
        availableNFTsForMint --;
        keyUsed[currentMerkleRound][myKey] = true;
        // alreadyMinted[currentSeriesId][collectionId][tokenId][level] = true;
    }

    function mintRewardBurnNFT() external payable nonReentrant {
        require(!burnNFTPaused, "nft burning is paused");
        require(balanceOf(msg.sender, nftSeriesId) > 0, "You don't own any nft");

        if (rewardSupplies[currentRewardSeriesId] <= 0) {
            require(rewardSupplies[currentRewardSeriesId + 1] > 0, "reward nft not ready yet");
            currentRewardSeriesId ++;
        }
        rewardSupplies[currentRewardSeriesId] -= 1;
        _burn(msg.sender, nftSeriesId, 1);
        _mint(msg.sender, currentRewardSeriesId, 1, "0x00");
    }

    function setNFTUri(string memory nftUri) external onlyOwner {
        tokenURI[nftSeriesId] = nftUri;
    }

    function uri(uint256 tokenId) override public view returns (string memory tokenUri) {
        tokenUri = tokenURI[tokenId];
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        payable(msg.sender).transfer(balance);
    }
}