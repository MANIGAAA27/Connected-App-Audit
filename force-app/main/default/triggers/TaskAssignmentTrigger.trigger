trigger TaskAssignmentTrigger on Task (after insert, after update) {
    AI_AssignmentHandler.handleTaskAssignments(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
}
