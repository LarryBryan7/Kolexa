-- CreateIndex
CREATE INDEX "gc_coursework_course_id_state_work_type_due_date_idx" ON "gc_coursework"("course_id", "state", "work_type", "due_date");

-- CreateIndex
CREATE INDEX "gc_student_submissions_coursework_id_submission_state_assigned_idx" ON "gc_student_submissions"("coursework_id", "submission_state", "assigned_grade");
