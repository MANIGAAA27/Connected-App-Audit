public with sharing class AI_AssignmentService {
    public static void assignRecords(List<sObject> records, String objectApiName) {
        if (records == null || records.isEmpty()) {
            return;
        }
        Assignment_Strategy__c strategy = fetchStrategy(objectApiName);

        Map<Id, Decimal> performanceAverages = new Map<Id, Decimal>();
        Map<Id, Decimal> workloadAverages = new Map<Id, Decimal>();
        for (AggregateResult aggregateRecord : [
            SELECT User__c userId, AVG(Score__c) avgScore, AVG(Workload__c) avgWorkload
            FROM Performance_Metric__c
            WHERE User__c != null
            GROUP BY User__c
        ]) {
            Id userId = (Id) aggregateRecord.get('userId');
            performanceAverages.put(userId, (Decimal) aggregateRecord.get('avgScore'));
            workloadAverages.put(userId, (Decimal) aggregateRecord.get('avgWorkload'));
        }

        Set<Id> candidateIds = new Set<Id>();
        candidateIds.addAll(performanceAverages.keySet());
        candidateIds.addAll(workloadAverages.keySet());
        candidateIds.addAll(AI_AssignmentDomain.getActiveUsers());

        Map<Id, Integer> skillCounts = AI_AssignmentDomain.getSkillCounts(candidateIds);

        Map<Id, User> userMap = new Map<Id, User>();
        if (!candidateIds.isEmpty()) {
            userMap = new Map<Id, User>([
                SELECT Id, Name
                FROM User
                WHERE IsActive = true AND Id IN :candidateIds
            ]);
        }

        String modelVersion = 'AI-Decision-v1-' + Datetime.now().format('yyyyMMddHHmm');
        List<sObject> updates = new List<sObject>();
        List<Assignment_Log__c> logs = new List<Assignment_Log__c>();

        AI_AssignmentCandidateWrapper globalWinner = findBestCandidate(
            userMap, performanceAverages, workloadAverages, skillCounts, strategy
        );

        for (sObject currentRecord : records) {
            Id recordId = (Id) currentRecord.get('Id');
            if (recordId == null) {
                continue;
            }
            Id existingOwner = (Id) currentRecord.get('OwnerId');
            Boolean assigned = false;

            if (globalWinner != null && globalWinner.userId != null) {
                if (existingOwner == null || existingOwner != globalWinner.userId) {
                    currentRecord.put('OwnerId', globalWinner.userId);
                    updates.add(currentRecord);
                }
                logs.add(AI_AssignmentLogger.buildLog(recordId, objectApiName, globalWinner, modelVersion, true));
                assigned = true;
            }

            if (!assigned && strategy != null && String.isNotBlank(strategy.Fallback_Owner_Id__c)) {
                currentRecord.put('OwnerId', strategy.Fallback_Owner_Id__c);
                updates.add(currentRecord);
                AI_AssignmentCandidateWrapper fallbackCandidate = new AI_AssignmentCandidateWrapper(
                    strategy.Fallback_Owner_Id__c, 0, 'Fallback owner configured', 'Fallback Owner'
                );
                logs.add(AI_AssignmentLogger.buildLog(recordId, objectApiName, fallbackCandidate, modelVersion, false));
                assigned = true;
            }

            if (!assigned) {
                logs.add(AI_AssignmentLogger.buildLog(recordId, objectApiName, null, modelVersion, false));
            }
        }

        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
        AI_AssignmentLogger.logBulk(logs);
    }

    private static AI_AssignmentCandidateWrapper findBestCandidate(
        Map<Id, User> userMap,
        Map<Id, Decimal> perfAverages,
        Map<Id, Decimal> workloadAverages,
        Map<Id, Integer> skillCounts,
        Assignment_Strategy__c strategy
    ) {
        Decimal topScore = -1;
        AI_AssignmentCandidateWrapper winner = null;
        for (Id userId : userMap.keySet()) {
            Decimal perfValue = perfAverages.containsKey(userId) ? perfAverages.get(userId) : null;
            Decimal workloadValue = workloadAverages.containsKey(userId) ? workloadAverages.get(userId) : null;
            Integer skillCount = skillCounts.containsKey(userId) ? skillCounts.get(userId) : 0;
            Decimal computedScore = computeScore(perfValue, workloadValue, skillCount, strategy);
            if (computedScore == null) {
                continue;
            }
            if (winner == null || computedScore > topScore) {
                topScore = computedScore;
                String reason = buildReason(perfValue, workloadValue, skillCount, strategy);
                winner = new AI_AssignmentCandidateWrapper(
                    userId, computedScore, reason, userMap.get(userId).Name
                );
            }
        }
        return winner;
    }

    private static Decimal computeScore(
        Decimal performance,
        Decimal workload,
        Integer skillCount,
        Assignment_Strategy__c strategy
    ) {
        Decimal perfWeight = (strategy != null && strategy.Weight_Performance__c != null)
            ? strategy.Weight_Performance__c : 40;
        Decimal workloadWeight = (strategy != null && strategy.Weight_Workload__c != null)
            ? strategy.Weight_Workload__c : 30;
        Decimal skillWeight = (strategy != null && strategy.Weight_Skill__c != null)
            ? strategy.Weight_Skill__c : 30;

        Decimal totalWeight = perfWeight + workloadWeight + skillWeight;
        if (totalWeight <= 0) {
            return null;
        }
        Decimal basePerf = (performance != null) ? Math.min(performance, 100) : 50;
        Decimal normalizedWorkload = (workload != null) ? Math.min(workload, 100) : 50;
        Decimal workloadScore = 100 - normalizedWorkload;
        Decimal normalizedSkill = Math.min((skillCount != null ? skillCount : 0), 5) * 20;
        Decimal weightedSum = (basePerf * perfWeight) + (workloadScore * workloadWeight) + (normalizedSkill * skillWeight);
        return (weightedSum / totalWeight).setScale(2, RoundingMode.HALF_UP);
    }

    private static String buildReason(
        Decimal performance,
        Decimal workload,
        Integer skillCount,
        Assignment_Strategy__c strategy
    ) {
        String perfReason = 'Performance ' + (performance != null ? String.valueOf(performance.setScale(1)) : '50');
        String workloadReason = 'Workload ' + (workload != null ? String.valueOf(workload.setScale(1)) : '50');
        String skillReason = 'Skill tags ' + (skillCount != null ? String.valueOf(skillCount) : '0');
        String objective = (strategy != null && String.isNotBlank(strategy.Objective__c))
            ? 'Objective ' + strategy.Objective__c : 'Objective Adaptive';
        return perfReason + ', ' + workloadReason + ', ' + skillReason + ', ' + objective;
    }

    private static Assignment_Strategy__c fetchStrategy(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return null;
        }
        List<Assignment_Strategy__c> strategies = [
            SELECT Id, Enabled__c, Objective__c, Weight_Performance__c, Weight_Workload__c,
                   Weight_Skill__c, Fallback_Owner_Id__c, Object_Target__c
            FROM Assignment_Strategy__c
            WHERE Enabled__c = true AND Object_Target__c = :objectApiName
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return strategies.isEmpty() ? null : strategies[0];
    }
}
