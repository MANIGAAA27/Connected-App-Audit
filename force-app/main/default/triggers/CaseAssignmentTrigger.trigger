trigger CaseAssignmentTrigger on Case (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            AI_AssignmentHandler.handleCaseAssignments(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
        }
    }
}