/**
 * PermissionAnalysisScheduler
 * Schedulable Apex that creates an Audit_Run__c header record and launches
 * PermissionAnalysisBatch. Guards against duplicate runs by checking for any
 * Audit_Run__c already in 'Scheduled' or 'In Progress' status.
 *
 * Schedule (nightly, 2 AM):
 *   System.schedule('Nightly Permission Audit', '0 0 2 * * ?',
 *                   new PermissionAnalysisScheduler());
 */
public with sharing class PermissionAnalysisScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        // Guard: only one active audit run at a time
        List<Audit_Run__c> activeRuns = [
            SELECT Id, Status__c
            FROM   Audit_Run__c
            WHERE  Status__c IN ('Scheduled', 'In Progress')
            LIMIT  1
        ];

        if (!activeRuns.isEmpty()) {
            // An audit is already running or scheduled — do nothing
            return;
        }

        Audit_Run__c newRun = new Audit_Run__c(
            Status__c       = 'Scheduled',
            Total_Findings__c = 0
        );
        insert newRun;

        Database.executeBatch(new PermissionAnalysisBatch(newRun.Id), 50);
    }
}
