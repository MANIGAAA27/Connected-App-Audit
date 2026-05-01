/**
 * PermissionAnalysisSchedulerTest
 * Covers PermissionAnalysisScheduler at 100% line coverage.
 * Validates scheduling, duplicate-run guard, and single-job enforcement.
 */
@isTest
private class PermissionAnalysisSchedulerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private static User buildAdminUser(String lastName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        return new User(
            LastName         = lastName,
            FirstName        = 'Test',
            Email            = lastName.toLowerCase() + '@keneland.com',
            Username         = lastName.toLowerCase() + Datetime.now().getTime() + '@keneland.com',
            Alias            = lastName.left(8),
            TimeZoneSidKey   = 'America/New_York',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId        = p.Id
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Positive: schedule executes, creates Audit_Run__c, launches batch
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testPositiveFlow_ScheduleJob() {
        User admin = buildAdminUser('SchedPos');
        insert admin;

        Integer runsBefore = [SELECT COUNT() FROM Audit_Run__c];

        Test.startTest();
        System.runAs(admin) {
            PermissionAnalysisScheduler sched = new PermissionAnalysisScheduler();
            String jobId = System.schedule(
                'Test Audit Scheduler Positive',
                '0 0 2 * * ?',
                sched
            );
            System.assertNotEquals(null, jobId, 'A valid CronTrigger ID should be returned.');
        }
        Test.stopTest();

        Integer runsAfter = [SELECT COUNT() FROM Audit_Run__c];
        System.assertEquals(runsBefore + 1, runsAfter,
            'Exactly one Audit_Run__c should be created per scheduler execution.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Negative: an active run already exists — scheduler should no-op
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testNegativeFlow_ActiveAuditRunExists() {
        User admin = buildAdminUser('SchedNeg');
        insert admin;

        // Pre-seed an In Progress run
        Audit_Run__c activeRun = new Audit_Run__c(
            Status__c         = 'In Progress',
            Total_Findings__c = 0
        );
        insert activeRun;

        Integer runsBefore = [SELECT COUNT() FROM Audit_Run__c];

        Test.startTest();
        System.runAs(admin) {
            PermissionAnalysisScheduler sched = new PermissionAnalysisScheduler();
            String jobId = System.schedule(
                'Test Audit Scheduler Negative',
                '0 0 3 * * ?',
                sched
            );
        }
        Test.stopTest();

        Integer runsAfter = [SELECT COUNT() FROM Audit_Run__c];
        System.assertEquals(runsBefore, runsAfter,
            'No new Audit_Run__c should be created when one is already active.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Bulk: scheduler invoked multiple times — only one job should launch
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testBulkScheduling_HandlesSingleRun() {
        User admin = buildAdminUser('SchedBulk');
        insert admin;

        Test.startTest();
        System.runAs(admin) {
            // First invocation should create a run
            PermissionAnalysisScheduler firstSched = new PermissionAnalysisScheduler();
            firstSched.execute(null);

            // Second invocation should be blocked by the guard
            PermissionAnalysisScheduler secondSched = new PermissionAnalysisScheduler();
            secondSched.execute(null);
        }
        Test.stopTest();

        Integer totalRuns = [SELECT COUNT() FROM Audit_Run__c];
        System.assertEquals(1, totalRuns,
            'Only one Audit_Run__c should exist even after two scheduler executions.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Edge: existing Scheduled status (not only In Progress) blocks new run
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testNegativeFlow_ScheduledStatusBlocksNewRun() {
        User admin = buildAdminUser('SchedEdge');
        insert admin;

        // Pre-seed a Scheduled run
        Audit_Run__c scheduledRun = new Audit_Run__c(
            Status__c         = 'Scheduled',
            Total_Findings__c = 0
        );
        insert scheduledRun;

        Integer runsBefore = [SELECT COUNT() FROM Audit_Run__c];

        Test.startTest();
        System.runAs(admin) {
            PermissionAnalysisScheduler sched = new PermissionAnalysisScheduler();
            sched.execute(null);
        }
        Test.stopTest();

        Integer runsAfter = [SELECT COUNT() FROM Audit_Run__c];
        System.assertEquals(runsBefore, runsAfter,
            'Scheduled status should also block a new run from being created.');
    }
}
