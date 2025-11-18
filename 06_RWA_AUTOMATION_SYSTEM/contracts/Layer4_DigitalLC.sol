// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRuleEngine {
    function isCompliant(address entity, uint256 minimumScore) external view returns (bool);
    function evaluateRule(uint256 ruleId, address subject, uint256 value) external returns (bool);
}

interface IAuditTrail {
    function recordEntry(
        uint8 eventType,
        uint8 severity,
        string memory description,
        bytes memory metadata
    ) external returns (uint256);
}

/**
 * @title DigitalLC
 * @notice Layer 4: Digital Letter of Credit Settlement System
 * @dev Automated settlement system with compliance integration
 */
contract DigitalLC is AccessControl, ReentrancyGuard {
    bytes32 public constant BANK_ROLE = keccak256("BANK_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant BENEFICIARY_ROLE = keccak256("BENEFICIARY_ROLE");

    IRuleEngine public ruleEngine;
    IAuditTrail public auditTrail;

    enum LCStatus {
        PENDING,
        ISSUED,
        DOCUMENTS_SUBMITTED,
        VERIFIED,
        SETTLED,
        CANCELLED,
        EXPIRED
    }

    enum DocumentType {
        BILL_OF_LADING,
        COMMERCIAL_INVOICE,
        PACKING_LIST,
        CERTIFICATE_OF_ORIGIN,
        INSURANCE_CERTIFICATE,
        INSPECTION_CERTIFICATE
    }

    struct LetterOfCredit {
        uint256 lcId;
        address issuer;
        address beneficiary;
        address advisingBank;
        uint256 amount;
        IERC20 currency;
        LCStatus status;
        uint256 expiryDate;
        uint256 issuedDate;
        uint256 settledDate;
        bytes32 termsHash;
        uint256 trustScore;
        bool autoSettle;
    }

    struct Document {
        uint256 documentId;
        uint256 lcId;
        DocumentType docType;
        bytes32 documentHash;
        address submitter;
        uint256 timestamp;
        bool isVerified;
        address verifier;
    }

    struct Settlement {
        uint256 settlementId;
        uint256 lcId;
        uint256 amount;
        uint256 timestamp;
        uint256 executionTime;
        bytes32 settlementHash;
        bool isCompleted;
    }

    // Storage
    mapping(uint256 => LetterOfCredit) public letterOfCredits;
    mapping(uint256 => Document[]) public lcDocuments;
    mapping(uint256 => Settlement) public settlements;
    mapping(address => uint256[]) public issuerLCs;
    mapping(address => uint256[]) public beneficiaryLCs;

    uint256 public lcCount;
    uint256 public settlementCount;
    uint256 public constant MINIMUM_TRUST_SCORE = 8000; // 80%
    uint256 public constant SETTLEMENT_DELAY = 1 days;

    // Events
    event LCIssued(
        uint256 indexed lcId,
        address indexed issuer,
        address indexed beneficiary,
        uint256 amount,
        uint256 expiryDate
    );

    event DocumentSubmitted(
        uint256 indexed lcId,
        uint256 indexed documentId,
        DocumentType docType,
        address submitter
    );

    event DocumentVerified(
        uint256 indexed lcId,
        uint256 indexed documentId,
        address verifier
    );

    event SettlementInitiated(
        uint256 indexed settlementId,
        uint256 indexed lcId,
        uint256 amount,
        uint256 executionTime
    );

    event SettlementCompleted(
        uint256 indexed settlementId,
        uint256 indexed lcId,
        uint256 amount,
        address beneficiary
    );

    event LCCancelled(
        uint256 indexed lcId,
        address canceller,
        string reason
    );

    constructor(address _ruleEngine, address _auditTrail) {
        require(_ruleEngine != address(0), "Invalid rule engine");
        require(_auditTrail != address(0), "Invalid audit trail");

        ruleEngine = IRuleEngine(_ruleEngine);
        auditTrail = IAuditTrail(_auditTrail);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Issue new Letter of Credit
     * @param beneficiary Beneficiary address
     * @param amount LC amount
     * @param currency Currency token
     * @param expiryDate Expiry timestamp
     * @param termsHash Hash of LC terms
     * @param autoSettle Enable auto-settlement
     */
    function issueLC(
        address beneficiary,
        uint256 amount,
        IERC20 currency,
        uint256 expiryDate,
        bytes32 termsHash,
        bool autoSettle
    ) external onlyRole(ISSUER_ROLE) nonReentrant returns (uint256) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Invalid amount");
        require(expiryDate > block.timestamp, "Invalid expiry");

        // Check issuer compliance
        require(
            ruleEngine.isCompliant(msg.sender, MINIMUM_TRUST_SCORE),
            "Issuer not compliant"
        );

        // Check beneficiary compliance
        require(
            ruleEngine.isCompliant(beneficiary, MINIMUM_TRUST_SCORE),
            "Beneficiary not compliant"
        );

        uint256 lcId = lcCount++;

        letterOfCredits[lcId] = LetterOfCredit({
            lcId: lcId,
            issuer: msg.sender,
            beneficiary: beneficiary,
            advisingBank: address(0),
            amount: amount,
            currency: currency,
            status: LCStatus.ISSUED,
            expiryDate: expiryDate,
            issuedDate: block.timestamp,
            settledDate: 0,
            termsHash: termsHash,
            trustScore: MINIMUM_TRUST_SCORE,
            autoSettle: autoSettle
        });

        issuerLCs[msg.sender].push(lcId);
        beneficiaryLCs[beneficiary].push(lcId);

        // Lock funds
        require(
            currency.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        emit LCIssued(lcId, msg.sender, beneficiary, amount, expiryDate);

        // Record in audit trail
        auditTrail.recordEntry(
            7, // SETTLEMENT_INITIATED
            0, // INFO
            "Letter of Credit issued",
            abi.encode(lcId, msg.sender, beneficiary, amount)
        );

        return lcId;
    }

    /**
     * @notice Submit document for LC
     * @param lcId LC ID
     * @param docType Document type
     * @param documentHash Document hash
     */
    function submitDocument(
        uint256 lcId,
        DocumentType docType,
        bytes32 documentHash
    ) external returns (uint256) {
        LetterOfCredit storage lc = letterOfCredits[lcId];
        require(lc.status == LCStatus.ISSUED, "LC not in valid state");
        require(
            msg.sender == lc.beneficiary || hasRole(BANK_ROLE, msg.sender),
            "Not authorized"
        );
        require(block.timestamp < lc.expiryDate, "LC expired");

        uint256 documentId = lcDocuments[lcId].length;

        lcDocuments[lcId].push(Document({
            documentId: documentId,
            lcId: lcId,
            docType: docType,
            documentHash: documentHash,
            submitter: msg.sender,
            timestamp: block.timestamp,
            isVerified: false,
            verifier: address(0)
        }));

        if (lc.status == LCStatus.ISSUED) {
            lc.status = LCStatus.DOCUMENTS_SUBMITTED;
        }

        emit DocumentSubmitted(lcId, documentId, docType, msg.sender);

        return documentId;
    }

    /**
     * @notice Verify submitted document
     * @param lcId LC ID
     * @param documentId Document ID
     */
    function verifyDocument(
        uint256 lcId,
        uint256 documentId
    ) external onlyRole(BANK_ROLE) {
        LetterOfCredit storage lc = letterOfCredits[lcId];
        require(
            lc.status == LCStatus.DOCUMENTS_SUBMITTED,
            "LC not in valid state"
        );

        Document storage doc = lcDocuments[lcId][documentId];
        require(!doc.isVerified, "Already verified");

        doc.isVerified = true;
        doc.verifier = msg.sender;

        emit DocumentVerified(lcId, documentId, msg.sender);

        // Check if all required documents are verified
        if (_areAllDocumentsVerified(lcId)) {
            lc.status = LCStatus.VERIFIED;

            // Auto-settle if enabled
            if (lc.autoSettle) {
                _initiateSettlement(lcId);
            }
        }
    }

    /**
     * @notice Check if all documents are verified
     */
    function _areAllDocumentsVerified(
        uint256 lcId
    ) internal view returns (bool) {
        Document[] memory docs = lcDocuments[lcId];

        if (docs.length < 3) {
            return false; // Minimum 3 documents required
        }

        for (uint256 i = 0; i < docs.length; i++) {
            if (!docs[i].isVerified) {
                return false;
            }
        }

        return true;
    }

    /**
     * @notice Initiate settlement
     * @param lcId LC ID
     */
    function _initiateSettlement(uint256 lcId) internal {
        LetterOfCredit storage lc = letterOfCredits[lcId];
        require(lc.status == LCStatus.VERIFIED, "LC not verified");

        uint256 settlementId = settlementCount++;
        uint256 executionTime = block.timestamp + SETTLEMENT_DELAY;

        bytes32 settlementHash = keccak256(
            abi.encodePacked(settlementId, lcId, lc.amount, executionTime)
        );

        settlements[settlementId] = Settlement({
            settlementId: settlementId,
            lcId: lcId,
            amount: lc.amount,
            timestamp: block.timestamp,
            executionTime: executionTime,
            settlementHash: settlementHash,
            isCompleted: false
        });

        emit SettlementInitiated(settlementId, lcId, lc.amount, executionTime);

        // Record in audit trail
        auditTrail.recordEntry(
            7, // SETTLEMENT_INITIATED
            0, // INFO
            "Settlement initiated",
            abi.encode(settlementId, lcId, lc.amount)
        );
    }

    /**
     * @notice Execute settlement
     * @param settlementId Settlement ID
     */
    function executeSettlement(
        uint256 settlementId
    ) external nonReentrant returns (bool) {
        Settlement storage settlement = settlements[settlementId];
        require(!settlement.isCompleted, "Already settled");
        require(
            block.timestamp >= settlement.executionTime,
            "Settlement delay not passed"
        );

        LetterOfCredit storage lc = letterOfCredits[settlement.lcId];
        require(lc.status == LCStatus.VERIFIED, "LC not verified");
        require(block.timestamp < lc.expiryDate, "LC expired");

        // Final compliance check
        require(
            ruleEngine.isCompliant(lc.beneficiary, MINIMUM_TRUST_SCORE),
            "Beneficiary not compliant"
        );

        // Transfer funds
        require(
            lc.currency.transfer(lc.beneficiary, settlement.amount),
            "Transfer failed"
        );

        settlement.isCompleted = true;
        lc.status = LCStatus.SETTLED;
        lc.settledDate = block.timestamp;

        emit SettlementCompleted(
            settlementId,
            settlement.lcId,
            settlement.amount,
            lc.beneficiary
        );

        // Record in audit trail
        auditTrail.recordEntry(
            8, // SETTLEMENT_COMPLETED
            0, // INFO
            "Settlement completed",
            abi.encode(settlementId, settlement.lcId, settlement.amount)
        );

        return true;
    }

    /**
     * @notice Cancel LC
     * @param lcId LC ID
     * @param reason Cancellation reason
     */
    function cancelLC(
        uint256 lcId,
        string memory reason
    ) external {
        LetterOfCredit storage lc = letterOfCredits[lcId];
        require(
            msg.sender == lc.issuer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(
            lc.status != LCStatus.SETTLED && lc.status != LCStatus.CANCELLED,
            "Cannot cancel"
        );

        // Return funds to issuer
        require(
            lc.currency.transfer(lc.issuer, lc.amount),
            "Transfer failed"
        );

        lc.status = LCStatus.CANCELLED;

        emit LCCancelled(lcId, msg.sender, reason);

        // Record in audit trail
        auditTrail.recordEntry(
            7, // SETTLEMENT_INITIATED (reusing)
            1, // WARNING
            "Letter of Credit cancelled",
            abi.encode(lcId, msg.sender, reason)
        );
    }

    /**
     * @notice Get LC details
     */
    function getLC(uint256 lcId) external view returns (LetterOfCredit memory) {
        return letterOfCredits[lcId];
    }

    /**
     * @notice Get LC documents
     */
    function getLCDocuments(
        uint256 lcId
    ) external view returns (Document[] memory) {
        return lcDocuments[lcId];
    }

    /**
     * @notice Get issuer LCs
     */
    function getIssuerLCs(
        address issuer
    ) external view returns (uint256[] memory) {
        return issuerLCs[issuer];
    }

    /**
     * @notice Get beneficiary LCs
     */
    function getBeneficiaryLCs(
        address beneficiary
    ) external view returns (uint256[] memory) {
        return beneficiaryLCs[beneficiary];
    }

    /**
     * @notice Add bank role
     */
    function addBank(address bank) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BANK_ROLE, bank);
    }

    /**
     * @notice Add issuer role
     */
    function addIssuer(address issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ISSUER_ROLE, issuer);
    }

    /**
     * @notice Add beneficiary role
     */
    function addBeneficiary(
        address beneficiary
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BENEFICIARY_ROLE, beneficiary);
    }
}
