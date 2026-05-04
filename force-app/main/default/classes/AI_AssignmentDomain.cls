public with sharing class AI_AssignmentDomain {
    public static Set<Id> getActiveUsers() {
        Set<Id> userIds = new Set<Id>();
        for (User currentUser : [
            SELECT Id
            FROM User
            WHERE IsActive = true
            LIMIT 200
        ]) {
            userIds.add(currentUser.Id);
        }
        return userIds;
    }

    public static Map<Id, Integer> getSkillCounts(Set<Id> userIds) {
        Map<Id, Integer> skillCounts = new Map<Id, Integer>();
        if (userIds.isEmpty()) {
            return skillCounts;
        }
        for (AggregateResult aggregateRecord : [
            SELECT Related_User__c userId, COUNT(Id) skillCount
            FROM Skill_Tag__c
            WHERE Related_User__c IN :userIds AND Is_Active__c = true
            GROUP BY Related_User__c
        ]) {
            Id userId = (Id)aggregateRecord.get('userId');
            Integer countValue = ((Decimal)aggregateRecord.get('skillCount')).intValue();
            skillCounts.put(userId, countValue);
        }
        return skillCounts;
    }
}
