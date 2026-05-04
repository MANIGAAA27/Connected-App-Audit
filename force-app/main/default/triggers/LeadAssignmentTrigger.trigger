trigger LeadAssignmentTrigger on Lead (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            AI_AssignmentHandler.handleLeadAssignments(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
        }
    }
}
