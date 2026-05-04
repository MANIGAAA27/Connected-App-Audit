public with sharing class AI_AssignmentAdminController {
    @AuraEnabled(cacheable=true)
    public static List<AssignmentStrategySummary> fetchStrategies() {
        List<Assignment_Strategy__c> strategies = [
            SELECT Id, Name, Objective__c, Weight_Performance__c, Weight_Workload__c, Weight_Skill__c, Enabled__c, Object_Target__c, Description__c
            FROM Assignment_Strategy__c
            ORDER BY LastModifiedDate DESC
        ];
        List<AssignmentStrategySummary> summaries = new List<AssignmentStrategySummary>();
        for (Assignment_Strategy__c item : strategies) {
            summaries.add(new AssignmentStrategySummary(item));
        }
        return summaries;
    }

    public class AssignmentStrategySummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String objective;
        @AuraEnabled public Decimal weightPerformance;
        @AuraEnabled public Decimal weightWorkload;
        @AuraEnabled public Decimal weightSkill;
        @AuraEnabled public Boolean enabled;
        @AuraEnabled public String objectTarget;
        @AuraEnabled public String description;

        public AssignmentStrategySummary(Assignment_Strategy__c strategy) {
            this.id = strategy.Id;
            this.name = strategy.Name;
            this.objective = strategy.Objective__c;
            this.weightPerformance = strategy.Weight_Performance__c;
            this.weightWorkload = strategy.Weight_Workload__c;
            this.weightSkill = strategy.Weight_Skill__c;
            this.enabled = strategy.Enabled__c;
            this.objectTarget = strategy.Object_Target__c;
            this.description = strategy.Description__c;
        }
    }
}
