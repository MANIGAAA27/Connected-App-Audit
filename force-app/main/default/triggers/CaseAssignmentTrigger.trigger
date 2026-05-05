trigger CaseAssignmentTrigger on Case (after insert, after update) {
    AI_AssignmentHandler.handleCaseAssignments(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
}
