public with sharing class AI_AssignmentLogger {
    public static void logBulk(List<Assignment_Log__c> logEntries) {
        if (logEntries == null || logEntries.isEmpty()) {
            return;
        }
        Database.insert(logEntries, false);
    }

    public static Assignment_Log__c buildLog(
        String recordId,
        String objectType,
        AI_AssignmentCandidateWrapper candidate,
        String modelVersion,
        Boolean usedAi
    ) {
        Assignment_Log__c logEntry = new Assignment_Log__c();
        logEntry.Record_Id__c = recordId;
        logEntry.Record_Type__c = objectType;
        logEntry.Model_Version__c = modelVersion;
        logEntry.Was_AI_Assigned__c = usedAi;
        if (candidate != null) {
            logEntry.Assigned_User__c = candidate.userId;
            logEntry.Score__c = candidate.score;
            logEntry.Top_Reason__c = candidate.reason;
            logEntry.Recommendation__c = 'Assigned to ' + candidate.userName;
        } else {
            logEntry.Recommendation__c = 'No eligible candidate was available';
            logEntry.Top_Reason__c = 'Fallback executed';
        }
        return logEntry;
    }
}
