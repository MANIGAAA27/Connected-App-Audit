public with sharing class AI_AssignmentRationaleController {
    @AuraEnabled(cacheable=true)
    public static List<AssignmentRationaleSummary> fetchLogs(Id recordId) {
        if (recordId == null) {
            return new List<AssignmentRationaleSummary>();
        }
        List<Assignment_Log__c> logs = [
            SELECT Id, Assigned_User__c, Assigned_User__r.Name, Score__c,
                   Top_Reason__c, Recommendation__c, CreatedDate
            FROM Assignment_Log__c
            WHERE Record_Id__c = :recordId
            ORDER BY CreatedDate DESC
            LIMIT 3
        ];
        List<AssignmentRationaleSummary> summaries = new List<AssignmentRationaleSummary>();
        for (Assignment_Log__c logItem : logs) {
            summaries.add(new AssignmentRationaleSummary(logItem));
        }
        return summaries;
    }

    public class AssignmentRationaleSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String assignedUserName;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String topReason;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String createdDate;

        public AssignmentRationaleSummary(Assignment_Log__c logItem) {
            this.id = logItem.Id;
            this.assignedUserName = (logItem.Assigned_User__r != null)
                ? logItem.Assigned_User__r.Name : 'Unassigned';
            this.score = logItem.Score__c;
            this.topReason = logItem.Top_Reason__c;
            this.recommendation = logItem.Recommendation__c;
            this.createdDate = (logItem.CreatedDate != null)
                ? logItem.CreatedDate.format() : null;
        }
    }
}
