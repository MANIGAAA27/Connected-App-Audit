trigger LeadAssignmentTrigger on Lead (after insert, after update) {
    AI_AssignmentHandler.handleLeadAssignments(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
}
