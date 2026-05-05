public with sharing class AI_AssignmentCandidateWrapper {
    @AuraEnabled public Id userId;
    @AuraEnabled public String userName;
    @AuraEnabled public Decimal score;
    @AuraEnabled public String reason;

    public AI_AssignmentCandidateWrapper(Id userId, Decimal score, String reason, String userName) {
        this.userId = userId;
        this.score = score;
        this.reason = reason;
        this.userName = userName;
    }
}