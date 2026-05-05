@isTest
private class AI_AssignmentTest {

    // ─── Shared test data setup ───────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        Profile profileRecord = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User aiUser = new User(
            Alias            = 'aitest',
            Email            = 'ai.optimizer.test@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName         = 'OptimizerUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey     = 'en_US',
            ProfileId        = profileRecord.Id,
            TimeZoneSidKey   = 'America/Los_Angeles',
            UserName         = 'ai.optimizer.' + System.currentTimeMillis() + '@keneland.example.com'
        );
        insert aiUser;

        Skill_Tag__c skillTag = new Skill_Tag__c(
            Name           = 'Cloud Services',
            Skill_Type__c  = 'Product',
            Is_Active__c   = true,
            Related_User__c = aiUser.Id
        );
        insert skillTag;

        Performance_Metric__c metricRecord = new Performance_Metric__c(
            User__c       = aiUser.Id,
            Metric_Date__c = Date.today(),
            Metric_Type__c = 'Conversion',
            Score__c      = 90,
            Workload__c   = 10
        );
        insert metricRecord;

        Assignment_Strategy__c leadStrategy = new Assignment_Strategy__c(
            Name                 = 'Lead Revenue Strategy',
            Objective__c         = 'Maximize Revenue',
            Weight_Performance__c = 50,
            Weight_Workload__c   = 25,
            Weight_Skill__c      = 25,
            Object_Target__c     = 'Lead',
            Enabled__c           = true
        );
        Assignment_Strategy__c caseStrategy = new Assignment_Strategy__c(
            Name                 = 'Case SLA Strategy',
            Objective__c         = 'Minimize SLA',
            Weight_Performance__c = 30,
            Weight_Workload__c   = 40,
            Weight_Skill__c      = 30,
            Object_Target__c     = 'Case',
            Enabled__c           = true
        );
        insert new List<Assignment_Strategy__c>{ leadStrategy, caseStrategy };
    }

    // ─── Helper ──────────────────────────────────────────────────────────────

    static User getAiUser() {
        return [SELECT Id FROM User WHERE Email = 'ai.optimizer.test@example.com' LIMIT 1];
    }

    // ─── Lead handler ────────────────────────────────────────────────────────

    @isTest
    static void testLeadHandlerAssignsToTopCandidate() {
        User aiUser = getAiUser();
        Lead testLead = new Lead(LastName = 'Prospect', Company = 'Keneland', Use_AI_Assignment__c = true);
        insert testLead;

        Test.startTest();
        AI_AssignmentHandler.handleLeadAssignments(new List<Lead>{ testLead }, null);
        Test.stopTest();

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(aiUser.Id, updated.OwnerId, 'Lead should be assigned to top-scored user');
    }

    @isTest
    static void testLeadHandlerSkipsRecordWithFlagOff() {
        Id originalOwner = UserInfo.getUserId();
        Lead testLead = new Lead(
            LastName             = 'SkipLead',
            Company              = 'Keneland',
            OwnerId              = originalOwner,
            Use_AI_Assignment__c = false
        );
        insert testLead;

        Test.startTest();
        AI_AssignmentHandler.handleLeadAssignments(new List<Lead>{ testLead }, null);
        Test.stopTest();

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(originalOwner, updated.OwnerId, 'Non-opted lead owner should not change');
    }

    @isTest
    static void testLeadHandlerNullAndEmptyInput() {
        Test.startTest();
        AI_AssignmentHandler.handleLeadAssignments(null, null);
        AI_AssignmentHandler.handleLeadAssignments(new List<Lead>(), null);
        Test.stopTest();
        System.assert(true, 'No exception for null/empty lead input');
    }

    // ─── Case handler ────────────────────────────────────────────────────────

    @isTest
    static void testCaseHandlerAssignsToTopCandidate() {
        User aiUser = getAiUser();
        Case testCase = new Case(Subject = 'AI Routed Case', Use_AI_Assignment__c = true);
        insert testCase;

        Test.startTest();
        AI_AssignmentHandler.handleCaseAssignments(new List<Case>{ testCase }, null);
        Test.stopTest();

        Case updated = [SELECT OwnerId FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(aiUser.Id, updated.OwnerId, 'Case should be assigned to top-scored user');
    }

    @isTest
    static void testCaseHandlerNullAndEmptyInput() {
        Test.startTest();
        AI_AssignmentHandler.handleCaseAssignments(null, null);
        AI_AssignmentHandler.handleCaseAssignments(new List<Case>(), null);
        Test.stopTest();
        System.assert(true, 'No exception for null/empty case input');
    }

    // ─── Task handler ────────────────────────────────────────────────────────

    @isTest
    static void testTaskHandlerAssignsToTopCandidate() {
        User aiUser = getAiUser();
        Task testTask = new Task(Subject = 'AI Routed Task', Use_AI_Assignment__c = true);
        insert testTask;

        Test.startTest();
        AI_AssignmentHandler.handleTaskAssignments(new List<Task>{ testTask }, null);
        Test.stopTest();

        Task updated = [SELECT OwnerId FROM Task WHERE Id = :testTask.Id];
        System.assertEquals(aiUser.Id, updated.OwnerId, 'Task should be assigned to top-scored user');
    }

    @isTest
    static void testTaskHandlerNullAndEmptyInput() {
        Test.startTest();
        AI_AssignmentHandler.handleTaskAssignments(null, null);
        AI_AssignmentHandler.handleTaskAssignments(new List<Task>(), null);
        Test.stopTest();
        System.assert(true, 'No exception for null/empty task input');
    }

    // ─── Fallback logic ──────────────────────────────────────────────────────

    @isTest
    static void testFallbackOwnerUsedWhenNoWinnerFound() {
        User fallbackUser = getAiUser();

        Assignment_Strategy__c taskStrategy = new Assignment_Strategy__c(
            Name                 = 'Task Fallback Strategy',
            Objective__c         = 'Balance Workload',
            Weight_Performance__c = 33,
            Weight_Workload__c   = 34,
            Weight_Skill__c      = 33,
            Object_Target__c     = 'Task',
            Enabled__c           = true,
            Fallback_Owner_Id__c = fallbackUser.Id
        );
        insert taskStrategy;

        Task testTask = new Task(Subject = 'Fallback Task', Use_AI_Assignment__c = true);
        insert testTask;

        Test.startTest();
        AI_AssignmentHandler.handleTaskAssignments(new List<Task>{ testTask }, null);
        Test.stopTest();

        Task updated = [SELECT OwnerId FROM Task WHERE Id = :testTask.Id];
        System.assertNotEquals(null, updated.OwnerId, 'Fallback owner should be assigned');
    }

    // ─── Bulk assignment ─────────────────────────────────────────────────────

    @isTest
    static void testBulkLeadAssignment() {
        User aiUser = getAiUser();
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 10; i++) {
            leads.add(new Lead(LastName = 'BulkLead' + i, Company = 'Keneland', Use_AI_Assignment__c = true));
        }
        insert leads;

        Test.startTest();
        AI_AssignmentHandler.handleLeadAssignments(leads, null);
        Test.stopTest();

        List<Lead> updated = [SELECT OwnerId FROM Lead WHERE Id IN :leads];
        for (Lead l : updated) {
            System.assertEquals(aiUser.Id, l.OwnerId, 'All bulk leads should be assigned to top-scored user');
        }
    }

    // ─── Logging ─────────────────────────────────────────────────────────────

    @isTest
    static void testAssignmentLogCreatedForLead() {
        Lead testLead = new Lead(LastName = 'LogLead', Company = 'Keneland', Use_AI_Assignment__c = true);
        insert testLead;

        Test.startTest();
        AI_AssignmentHandler.handleLeadAssignments(new List<Lead>{ testLead }, null);
        Test.stopTest();

        List<Assignment_Log__c> logs = [
            SELECT Id, Record_Type__c, Was_AI_Assigned__c, Score__c, Top_Reason__c
            FROM Assignment_Log__c
            WHERE Record_Id__c = :testLead.Id
        ];
        System.assertFalse(logs.isEmpty(), 'Assignment log must be created');
        System.assertEquals('Lead', logs[0].Record_Type__c);
        System.assertNotEquals(null, logs[0].Score__c, 'Score should be populated');
        System.assertNotEquals(null, logs[0].Top_Reason__c, 'Top reason should be populated');
    }

    @isTest
    static void testLoggerBuildLogWithNullCandidate() {
        Assignment_Log__c logEntry = AI_AssignmentLogger.buildLog('001000000000001AAA', 'Lead', null, 'v-test', false);
        System.assertNotEquals(null, logEntry);
        System.assertEquals('Fallback executed', logEntry.Top_Reason__c);
        System.assertEquals('No eligible candidate was available', logEntry.Recommendation__c);
    }

    @isTest
    static void testLoggerBulkWithNullAndEmpty() {
        Test.startTest();
        AI_AssignmentLogger.logBulk(null);
        AI_AssignmentLogger.logBulk(new List<Assignment_Log__c>());
        Test.stopTest();
        System.assert(true, 'No exception for null/empty log bulk');
    }

    // ─── Domain layer ────────────────────────────────────────────────────────

    @isTest
    static void testGetActiveUsersReturnsNonEmptySet() {
        Test.startTest();
        Set<Id> userIds = AI_AssignmentDomain.getActiveUsers();
        Test.stopTest();
        System.assertFalse(userIds.isEmpty(), 'getActiveUsers must return at least one user');
    }

    @isTest
    static void testGetSkillCountsForKnownUser() {
        User aiUser = getAiUser();
        Test.startTest();
        Map<Id, Integer> counts = AI_AssignmentDomain.getSkillCounts(new Set<Id>{ aiUser.Id });
        Test.stopTest();
        System.assertTrue(counts.containsKey(aiUser.Id), 'Skill count entry should exist for aiUser');
        System.assertEquals(1, counts.get(aiUser.Id), 'Skill count should be 1');
    }

    @isTest
    static void testGetSkillCountsEmptySetReturnsEmpty() {
        Test.startTest();
        Map<Id, Integer> counts = AI_AssignmentDomain.getSkillCounts(new Set<Id>());
        Test.stopTest();
        System.assertTrue(counts.isEmpty(), 'Empty input should return empty map');
    }

    @isTest
    static void testGetSkillCountsNullSetReturnsEmpty() {
        Test.startTest();
        Map<Id, Integer> counts = AI_AssignmentDomain.getSkillCounts(null);
        Test.stopTest();
        System.assertTrue(counts.isEmpty(), 'Null input should return empty map');
    }

    // ─── Flow invoker ────────────────────────────────────────────────────────

    @isTest
    static void testFlowInvokerAssignsLeadCorrectly() {
        User aiUser = getAiUser();
        Lead testLead = new Lead(LastName = 'FlowLead', Company = 'Keneland', Use_AI_Assignment__c = true);
        insert testLead;

        AI_AssignmentFlowInvoker.FlowAssignmentRequest req = new AI_AssignmentFlowInvoker.FlowAssignmentRequest();
        req.recordId = testLead.Id;
        req.objectType = 'Lead';

        Test.startTest();
        AI_AssignmentFlowInvoker.assignRecordsViaFlow(new List<AI_AssignmentFlowInvoker.FlowAssignmentRequest>{ req });
        Test.stopTest();

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(aiUser.Id, updated.OwnerId, 'Flow invoker should assign lead to top-scored user');
    }

    @isTest
    static void testFlowInvokerIgnoresDisallowedObjectType() {
        Lead testLead = new Lead(LastName = 'DisallowedLead', Company = 'Keneland', Use_AI_Assignment__c = true);
        insert testLead;
        Id originalOwner = [SELECT OwnerId FROM Lead WHERE Id = :testLead.Id].OwnerId;

        AI_AssignmentFlowInvoker.FlowAssignmentRequest req = new AI_AssignmentFlowInvoker.FlowAssignmentRequest();
        req.recordId = testLead.Id;
        req.objectType = 'Account';

        Test.startTest();
        AI_AssignmentFlowInvoker.assignRecordsViaFlow(new List<AI_AssignmentFlowInvoker.FlowAssignmentRequest>{ req });
        Test.stopTest();

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(originalOwner, updated.OwnerId, 'Disallowed object type must not change owner');
    }

    @isTest
    static void testFlowInvokerNullAndEmptyInput() {
        Test.startTest();
        AI_AssignmentFlowInvoker.assignRecordsViaFlow(null);
        AI_AssignmentFlowInvoker.assignRecordsViaFlow(new List<AI_AssignmentFlowInvoker.FlowAssignmentRequest>());
        Test.stopTest();
        System.assert(true, 'No exception for null/empty flow requests');
    }

    @isTest
    static void testFlowInvokerSkipsNullRequest() {
        List<AI_AssignmentFlowInvoker.FlowAssignmentRequest> requests =
            new List<AI_AssignmentFlowInvoker.FlowAssignmentRequest>{ null };
        Test.startTest();
        AI_AssignmentFlowInvoker.assignRecordsViaFlow(requests);
        Test.stopTest();
        System.assert(true, 'Null list element should be silently skipped');
    }

    // ─── Admin controller ────────────────────────────────────────────────────

    @isTest
    static void testAdminControllerFetchStrategiesReturnsData() {
        Test.startTest();
        List<AI_AssignmentAdminController.AssignmentStrategySummary> result =
            AI_AssignmentAdminController.fetchStrategies();
        Test.stopTest();
        System.assertFalse(result.isEmpty(), 'fetchStrategies should return at least the seeded strategies');
        Boolean foundLead = false;
        for (AI_AssignmentAdminController.AssignmentStrategySummary s : result) {
            if (s.objectTarget == 'Lead') {
                foundLead = true;
                System.assertEquals('Maximize Revenue', s.objective);
                System.assertEquals(true, s.enabled);
            }
        }
        System.assertTrue(foundLead, 'Lead strategy should be in results');
    }

    // ─── Rationale controller ────────────────────────────────────────────────

    @isTest
    static void testRationaleControllerFetchLogsReturnsEntries() {
        Lead testLead = new Lead(LastName = 'RationaleLead', Company = 'Keneland', Use_AI_Assignment__c = true);
        insert testLead;
        AI_AssignmentHandler.handleLeadAssignments(new List<Lead>{ testLead }, null);

        Test.startTest();
        List<AI_AssignmentRationaleController.AssignmentRationaleSummary> result =
            AI_AssignmentRationaleController.fetchLogs(testLead.Id);
        Test.stopTest();

        System.assertFalse(result.isEmpty(), 'Rationale controller should return log entries');
        System.assertNotEquals(null, result[0].topReason, 'Top reason should be populated');
        System.assertNotEquals(null, result[0].recommendation, 'Recommendation should be populated');
    }

    @isTest
    static void testRationaleControllerNullIdReturnsEmpty() {
        Test.startTest();
        List<AI_AssignmentRationaleController.AssignmentRationaleSummary> result =
            AI_AssignmentRationaleController.fetchLogs(null);
        Test.stopTest();
        System.assertTrue(result.isEmpty(), 'Null record Id should return empty list');
    }

    // ─── Service: no active strategy ─────────────────────────────────────────

    @isTest
    static void testServiceWithNoEnabledStrategy() {
        List<Assignment_Strategy__c> all = [SELECT Id, Enabled__c FROM Assignment_Strategy__c];
        for (Assignment_Strategy__c s : all) {
            s.Enabled__c = false;
        }
        update all;

        Lead testLead = new Lead(LastName = 'NoStratLead', Company = 'Keneland', Use_AI_Assignment__c = true);
        insert testLead;

        Test.startTest();
        AI_AssignmentService.assignRecords(new List<sObject>{ testLead }, 'Lead');
        Test.stopTest();

        System.assert(true, 'Service should handle missing strategy without exception');
    }

    @isTest
    static void testServiceWithNullAndEmptyRecords() {
        Test.startTest();
        AI_AssignmentService.assignRecords(null, 'Lead');
        AI_AssignmentService.assignRecords(new List<sObject>(), 'Lead');
        Test.stopTest();
        System.assert(true, 'Service should handle null/empty record list without exception');
    }

    // ─── Trigger layer (end-to-end via DML) ──────────────────────────────────

    @isTest
    static void testLeadTriggerEndToEnd() {
        User aiUser = getAiUser();
        Test.startTest();
        Lead testLead = new Lead(LastName = 'TriggerLead', Company = 'Keneland', Use_AI_Assignment__c = true);
        insert testLead;
        Test.stopTest();

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(aiUser.Id, updated.OwnerId, 'Trigger should assign lead end-to-end');
    }

    @isTest
    static void testCaseTriggerEndToEnd() {
        User aiUser = getAiUser();
        Test.startTest();
        Case testCase = new Case(Subject = 'E2E Case', Use_AI_Assignment__c = true);
        insert testCase;
        Test.stopTest();

        Case updated = [SELECT OwnerId FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(aiUser.Id, updated.OwnerId, 'Trigger should assign case end-to-end');
    }

    @isTest
    static void testTaskTriggerEndToEnd() {
        User aiUser = getAiUser();
        Test.startTest();
        Task testTask = new Task(Subject = 'E2E Task', Use_AI_Assignment__c = true);
        insert testTask;
        Test.stopTest();

        Task updated = [SELECT OwnerId FROM Task WHERE Id = :testTask.Id];
        System.assertEquals(aiUser.Id, updated.OwnerId, 'Trigger should assign task end-to-end');
    }
}
