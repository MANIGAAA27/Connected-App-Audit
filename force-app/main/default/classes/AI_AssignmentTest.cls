@isTest
private class AI_AssignmentTest {
    public static testMethod void testLeadAssignmentFlow() {
        Profile profileRecord = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User aiUser = new User(
            Alias = 'aiuser',
            Email = 'ai.assigner.test@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Optimizer',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'ai.assigner.test.' + System.currentTimeMillis() + '@example.com'
        );
        insert aiUser;
        Skill_Tag__c skillTag = new Skill_Tag__c(
            Name = 'High Priority',
            Skill_Type__c = 'Product',
            Is_Active__c = true,
            Related_User__c = aiUser.Id
        );
        insert skillTag;
        Performance_Metric__c metricRecord = new Performance_Metric__c(
            User__c = aiUser.Id,
            Metric_Date__c = Date.today(),
            Metric_Type__c = 'Conversion',
            Score__c = 92,
            Workload__c = 5
        );
        insert metricRecord;
        Assignment_Strategy__c strategy = new Assignment_Strategy__c(
            Name = 'Lead Revenue Bias',
            Objective__c = 'Maximize Revenue',
            Weight_Performance__c = 50,
            Weight_Workload__c = 25,
            Weight_Skill__c = 25,
            Object_Target__c = 'Lead',
            Enabled__c = true
        );
        insert strategy;
        Lead testLead = new Lead(
            LastName = 'Opportunity',
            Company = 'Keneland',
            Use_AI_Assignment__c = true
        );
        insert testLead;
        Test.startTest();
        AI_AssignmentHandler.handleLeadAssignments(new List<Lead>{testLead}, null);
        Test.stopTest();
        Lead refreshedLead = [SELECT OwnerId FROM Lead WHERE Id = :testLead.Id LIMIT 1];
        System.assertEquals(aiUser.Id, refreshedLead.OwnerId);
        Assignment_Log__c logRecord = [SELECT Id, Assigned_User__c, Record_Type__c FROM Assignment_Log__c WHERE Record_Id__c = :testLead.Id LIMIT 1];
        System.assertEquals('Lead', logRecord.Record_Type__c);
        System.assertEquals(aiUser.Id, logRecord.Assigned_User__c);
    }
}