public with sharing class AI_AssignmentHandler {
    public static void handleLeadAssignments(List<Lead> newRecords, Map<Id, Lead> oldMap) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }
        List<Lead> candidates = new List<Lead>();
        for (Lead record : newRecords) {
            if (Boolean.TRUE.equals(record.Use_AI_Assignment__c)) {
                candidates.add(record);
            }
        }
        if (!candidates.isEmpty()) {
            AI_AssignmentService.assignRecords(candidates, 'Lead');
        }
    }

    public static void handleCaseAssignments(List<Case> newRecords, Map<Id, Case> oldMap) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }
        List<Case> candidates = new List<Case>();
        for (Case record : newRecords) {
            if (Boolean.TRUE.equals(record.Use_AI_Assignment__c)) {
                candidates.add(record);
            }
        }
        if (!candidates.isEmpty()) {
            AI_AssignmentService.assignRecords(candidates, 'Case');
        }
    }

    public static void handleTaskAssignments(List<Task> newRecords, Map<Id, Task> oldMap) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }
        List<Task> candidates = new List<Task>();
        for (Task record : newRecords) {
            if (Boolean.TRUE.equals(record.Use_AI_Assignment__c)) {
                candidates.add(record);
            }
        }
        if (!candidates.isEmpty()) {
            AI_AssignmentService.assignRecords(candidates, 'Task');
        }
    }
}