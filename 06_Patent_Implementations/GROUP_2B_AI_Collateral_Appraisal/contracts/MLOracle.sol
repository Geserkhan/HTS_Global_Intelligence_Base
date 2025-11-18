// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MLOracle
 * @notice Decentralized ML oracle for off-chain model inference and on-chain result submission
 * @dev Coordinates between off-chain ML workers and on-chain appraisal contracts
 */
contract MLOracle {

    // ============ Structures ============

    struct InferenceJob {
        uint256 jobId;
        address requester;
        bytes32 modelHash;
        bytes inputData;         // Encoded feature vector
        JobStatus status;
        uint256 createdAt;
        uint256 completedAt;
        bytes result;            // Encoded ML prediction
        address worker;
    }

    struct MLWorker {
        address workerAddress;
        uint256 stake;
        uint256 completedJobs;
        uint256 failedJobs;
        uint256 reputationScore;  // 0-100
        bool isActive;
        uint256 registeredAt;
    }

    struct Prediction {
        uint256 predictedValue;
        uint256 confidenceScore;
        uint256 riskScore;
        bytes32 modelHash;
        uint256 timestamp;
    }

    enum JobStatus {
        Pending,
        Assigned,
        Computing,
        Completed,
        Failed,
        Disputed
    }

    // ============ State Variables ============

    mapping(uint256 => InferenceJob) public jobs;
    mapping(address => MLWorker) public workers;
    mapping(uint256 => Prediction) public predictions;
    mapping(bytes32 => address[]) public modelWorkers;

    address public appraisalContract;
    address public admin;

    uint256 public jobCounter;
    uint256 public minWorkerStake = 1000 ether;  // Minimum stake to become worker
    uint256 public jobReward = 10 ether;         // Reward per job
    uint256 public disputeWindow = 1 hours;      // Time to dispute results

    // ============ Events ============

    event JobCreated(
        uint256 indexed jobId,
        address indexed requester,
        bytes32 modelHash,
        uint256 timestamp
    );

    event JobAssigned(
        uint256 indexed jobId,
        address indexed worker,
        uint256 timestamp
    );

    event JobCompleted(
        uint256 indexed jobId,
        address indexed worker,
        bytes result,
        uint256 timestamp
    );

    event WorkerRegistered(
        address indexed worker,
        uint256 stake,
        uint256 timestamp
    );

    event ReputationUpdated(
        address indexed worker,
        uint256 newReputation,
        uint256 completedJobs
    );

    event DisputeRaised(
        uint256 indexed jobId,
        address indexed disputer,
        string reason
    );

    // ============ Modifiers ============

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyActiveWorker() {
        require(workers[msg.sender].isActive, "Not active worker");
        require(workers[msg.sender].stake >= minWorkerStake, "Insufficient stake");
        _;
    }

    modifier onlyAppraisalContract() {
        require(msg.sender == appraisalContract, "Only appraisal contract");
        _;
    }

    // ============ Constructor ============

    constructor(address _appraisalContract) {
        admin = msg.sender;
        appraisalContract = _appraisalContract;
    }

    // ============ Worker Management ============

    /**
     * @notice Register as an ML worker
     * @param modelHashes Array of model hashes this worker can serve
     */
    function registerWorker(
        bytes32[] calldata modelHashes
    ) external payable {
        require(msg.value >= minWorkerStake, "Insufficient stake");
        require(!workers[msg.sender].isActive, "Already registered");

        workers[msg.sender] = MLWorker({
            workerAddress: msg.sender,
            stake: msg.value,
            completedJobs: 0,
            failedJobs: 0,
            reputationScore: 50,  // Start at neutral reputation
            isActive: true,
            registeredAt: block.timestamp
        });

        // Add worker to model registries
        for (uint256 i = 0; i < modelHashes.length; i++) {
            modelWorkers[modelHashes[i]].push(msg.sender);
        }

        emit WorkerRegistered(msg.sender, msg.value, block.timestamp);
    }

    /**
     * @notice Increase worker stake
     */
    function increaseStake() external payable onlyActiveWorker {
        workers[msg.sender].stake += msg.value;
    }

    /**
     * @notice Withdraw stake and deregister
     */
    function withdrawStake() external onlyActiveWorker {
        MLWorker storage worker = workers[msg.sender];
        require(worker.completedJobs > 0, "Must complete at least 1 job");

        uint256 stakeAmount = worker.stake;
        worker.isActive = false;
        worker.stake = 0;

        payable(msg.sender).transfer(stakeAmount);
    }

    // ============ Job Management ============

    /**
     * @notice Create ML inference job
     * @param modelHash Hash of ML model to use
     * @param inputData Encoded input features
     * @return jobId Unique job identifier
     */
    function createJob(
        bytes32 modelHash,
        bytes calldata inputData
    ) external returns (uint256 jobId) {
        jobId = ++jobCounter;

        jobs[jobId] = InferenceJob({
            jobId: jobId,
            requester: msg.sender,
            modelHash: modelHash,
            inputData: inputData,
            status: JobStatus.Pending,
            createdAt: block.timestamp,
            completedAt: 0,
            result: "",
            worker: address(0)
        });

        emit JobCreated(jobId, msg.sender, modelHash, block.timestamp);

        return jobId;
    }

    /**
     * @notice Worker claims a job for processing
     * @param jobId Job to claim
     */
    function claimJob(uint256 jobId) external onlyActiveWorker {
        InferenceJob storage job = jobs[jobId];
        require(job.status == JobStatus.Pending, "Job not available");

        // Verify worker can serve this model
        bool canServe = false;
        address[] memory validWorkers = modelWorkers[job.modelHash];
        for (uint256 i = 0; i < validWorkers.length; i++) {
            if (validWorkers[i] == msg.sender) {
                canServe = true;
                break;
            }
        }
        require(canServe, "Worker cannot serve this model");

        job.status = JobStatus.Assigned;
        job.worker = msg.sender;

        emit JobAssigned(jobId, msg.sender, block.timestamp);
    }

    /**
     * @notice Submit job result
     * @param jobId Job identifier
     * @param result Encoded ML prediction result
     */
    function submitResult(
        uint256 jobId,
        bytes calldata result
    ) external onlyActiveWorker {
        InferenceJob storage job = jobs[jobId];
        require(job.worker == msg.sender, "Not assigned to you");
        require(job.status == JobStatus.Assigned, "Invalid status");

        job.result = result;
        job.status = JobStatus.Completed;
        job.completedAt = block.timestamp;

        // Decode prediction
        (uint256 value, uint256 confidence, uint256 risk) = abi.decode(
            result,
            (uint256, uint256, uint256)
        );

        predictions[jobId] = Prediction({
            predictedValue: value,
            confidenceScore: confidence,
            riskScore: risk,
            modelHash: job.modelHash,
            timestamp: block.timestamp
        });

        // Update worker stats
        MLWorker storage worker = workers[msg.sender];
        worker.completedJobs++;
        _updateReputation(msg.sender, true);

        // Pay worker
        payable(msg.sender).transfer(jobReward);

        emit JobCompleted(jobId, msg.sender, result, block.timestamp);
    }

    /**
     * @notice Raise dispute on a job result
     * @param jobId Job to dispute
     * @param reason Reason for dispute
     */
    function raiseDispute(
        uint256 jobId,
        string calldata reason
    ) external {
        InferenceJob storage job = jobs[jobId];
        require(job.requester == msg.sender, "Not job requester");
        require(job.status == JobStatus.Completed, "Job not completed");
        require(
            block.timestamp <= job.completedAt + disputeWindow,
            "Dispute window closed"
        );

        job.status = JobStatus.Disputed;

        emit DisputeRaised(jobId, msg.sender, reason);
    }

    /**
     * @notice Admin resolves dispute
     * @param jobId Job in dispute
     * @param workerAtFault Whether worker was at fault
     */
    function resolveDispute(
        uint256 jobId,
        bool workerAtFault
    ) external onlyAdmin {
        InferenceJob storage job = jobs[jobId];
        require(job.status == JobStatus.Disputed, "Not disputed");

        if (workerAtFault) {
            // Slash worker stake
            MLWorker storage worker = workers[job.worker];
            uint256 slashAmount = worker.stake / 10;  // 10% slash
            worker.stake -= slashAmount;
            worker.failedJobs++;
            _updateReputation(job.worker, false);

            // Refund requester
            payable(job.requester).transfer(jobReward);

            job.status = JobStatus.Failed;
        } else {
            job.status = JobStatus.Completed;
        }
    }

    // ============ Reputation System ============

    /**
     * @dev Update worker reputation based on performance
     * @param workerAddress Address of worker
     * @param success Whether job was successful
     */
    function _updateReputation(
        address workerAddress,
        bool success
    ) internal {
        MLWorker storage worker = workers[workerAddress];

        uint256 totalJobs = worker.completedJobs + worker.failedJobs;
        if (totalJobs == 0) {
            return;
        }

        // Reputation = (completedJobs / totalJobs) * 100
        uint256 newReputation = (worker.completedJobs * 100) / totalJobs;

        // Apply adjustment for success/failure
        if (success && worker.reputationScore < 100) {
            newReputation = (newReputation + worker.reputationScore) / 2 + 1;
        } else if (!success && worker.reputationScore > 0) {
            newReputation = (newReputation + worker.reputationScore) / 2 - 5;
        }

        worker.reputationScore = newReputation > 100 ? 100 : newReputation;

        emit ReputationUpdated(
            workerAddress,
            worker.reputationScore,
            worker.completedJobs
        );
    }

    // ============ View Functions ============

    /**
     * @notice Get job details
     * @param jobId Job identifier
     * @return InferenceJob struct
     */
    function getJob(uint256 jobId) external view returns (InferenceJob memory) {
        return jobs[jobId];
    }

    /**
     * @notice Get prediction for a job
     * @param jobId Job identifier
     * @return Prediction struct
     */
    function getPrediction(uint256 jobId) external view returns (Prediction memory) {
        return predictions[jobId];
    }

    /**
     * @notice Get worker details
     * @param workerAddress Worker address
     * @return MLWorker struct
     */
    function getWorker(address workerAddress) external view returns (MLWorker memory) {
        return workers[workerAddress];
    }

    /**
     * @notice Get workers for a specific model
     * @param modelHash Model hash
     * @return Array of worker addresses
     */
    function getModelWorkers(bytes32 modelHash) external view returns (address[] memory) {
        return modelWorkers[modelHash];
    }

    /**
     * @notice Get best worker for a model (highest reputation)
     * @param modelHash Model hash
     * @return bestWorker Address of best worker
     */
    function getBestWorker(bytes32 modelHash) external view returns (address bestWorker) {
        address[] memory validWorkers = modelWorkers[modelHash];
        uint256 highestReputation = 0;

        for (uint256 i = 0; i < validWorkers.length; i++) {
            MLWorker memory worker = workers[validWorkers[i]];
            if (worker.isActive && worker.reputationScore > highestReputation) {
                highestReputation = worker.reputationScore;
                bestWorker = validWorkers[i];
            }
        }

        return bestWorker;
    }

    // ============ Admin Functions ============

    /**
     * @notice Update job reward
     * @param newReward New reward amount
     */
    function updateJobReward(uint256 newReward) external onlyAdmin {
        jobReward = newReward;
    }

    /**
     * @notice Update minimum worker stake
     * @param newStake New stake amount
     */
    function updateMinStake(uint256 newStake) external onlyAdmin {
        minWorkerStake = newStake;
    }

    /**
     * @notice Update appraisal contract
     * @param newContract New contract address
     */
    function updateAppraisalContract(address newContract) external onlyAdmin {
        require(newContract != address(0), "Invalid contract");
        appraisalContract = newContract;
    }

    /**
     * @notice Emergency withdraw
     */
    function emergencyWithdraw() external onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    /**
     * @notice Update admin
     * @param newAdmin New admin address
     */
    function updateAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin");
        admin = newAdmin;
    }

    // ============ Fallback ============

    receive() external payable {}
}
