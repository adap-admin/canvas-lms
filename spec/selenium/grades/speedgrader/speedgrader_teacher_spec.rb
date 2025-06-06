# frozen_string_literal: true

#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

require_relative "../../common"
require_relative "../../helpers/speed_grader_common"
require_relative "../../helpers/gradebook_common"
require_relative "../../helpers/quizzes_common"
require_relative "../../helpers/groups_common"
require_relative "../pages/speedgrader_page"

describe "SpeedGrader" do
  include_context "in-process server selenium tests"
  include QuizzesCommon
  include GradebookCommon
  include SpeedGraderCommon
  include GroupsCommon

  before do
    stub_kaltura
    course_with_teacher_logged_in
    @assignment = @course.assignments.create(name: "assignment with rubric", points_possible: 10)
  end

  context "as a course limited ta" do
    before do
      @taenrollment = course_with_ta(course: @course, active_all: true)
      @taenrollment.limit_privileges_to_course_section = true
      @taenrollment.save!
      user_logged_in(user: @ta, username: "imata@example.com")

      @section = @course.course_sections.create!
      student_in_course(active_all: true)
      @student1 = @student
      student_in_course(active_all: true)
      @student2 = @student
      @enrollment.course_section = @section
      @enrollment.save

      @assignment.submission_types = "online_upload"
      @assignment.save!

      @submission1 = @assignment.submit_homework(@student1, submission_type: "online_text_entry", body: "hi")
      @submission2 = @assignment.submit_homework(@student2, submission_type: "online_text_entry", body: "there")
    end

    it "lists the correct number of students", priority: "2" do
      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

      expect(f("#x_of_x_students_frd")).to include_text("1/1")
      expect(ff("#students_selectmenu-menu li")).to have_size 1
    end
  end

  context "alerts" do
    it "alerts the teacher before leaving the page if comments are not saved", priority: "1" do
      student_in_course(active_user: true).user
      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"
      comment_textarea = f("#speed_grader_comment_textarea")
      replace_content(comment_textarea, "oh no i forgot to save this comment!")
      # navigate away
      driver.navigate.refresh
      alert_shown = alert_present?
      dismiss_alert
      expect(alert_shown).to be(true)
    end
  end

  context "url submissions" do
    before do
      @assignment.update! submission_types: "online_url",
                          title: "url submission"
      student_in_course
      @assignment.submit_homework(@student, submission_type: "online_url", workflow_state: "submitted", url: "http://www.instructure.com")
    end

    it "properly shows and hides student name when name hidden toggled", priority: "2" do
      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

      in_frame "speedgrader_iframe", ".is-inside-submission-frame" do
        expect(f(".not_external")).to include_text("instructure")
        expect(f(".open_in_a_new_tab")).to include_text("View")
      end
    end
  end

  it "does not show students in other sections if visibility is limited", priority: "1" do
    @enrollment.update_attribute(:limit_privileges_to_course_section, true)
    student_submission
    student_submission(username: "otherstudent@example.com", section: @course.course_sections.create(name: "another section"))
    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

    expect(ff("#students_selectmenu option")).to have_size 1 # just the one student
    expect(ff("#section-menu ul li")).to have_size 1 # "Show all sections"
    expect(f("#students_selectmenu")).not_to contain_css("#section-menu") # doesn't get inserted into the menu
  end

  it "displays inactive students" do
    @teacher.preferences = { gradebook_settings: { @course.id => { "show_inactive_enrollments" => "true" } } }
    @teacher.save

    student_submission(username: "inactivestudent@example.com")
    en = @student.student_enrollments.first
    en.deactivate

    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

    expect(ff("#students_selectmenu option")).to have_size 1 # just the one student
    expect(f("#enrollment_inactive_notice")).to include_text "Notice: Inactive Student"
  end

  it "can grade and comment inactive students" do
    @teacher.preferences = { gradebook_settings: { @course.id => { "show_inactive_enrollments" => "true" } } }
    @teacher.save

    student_submission(username: "inactivestudent@example.com")
    en = @student.student_enrollments.first
    en.deactivate

    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

    replace_content f("#grading-box-extended"), "5", tab_out: true
    expect { @submission.reload.score }.to become 5

    f("#speed_grader_comment_textarea").send_keys("srsly")
    f('#add_a_comment button[type="submit"]').click
    expect { @submission.submission_comments.where(comment: "srsly").any? }.to become(true)
    # doesn't get inserted into the menu
    expect(f("#students_selectmenu")).not_to contain_css("#section-menu")
  end

  it "can grade and comment active students", :xbrowser do
    student_submission(username: "activestudent@example.com")

    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

    replace_content f("#grading-box-extended"), "5", tab_out: true
    expect { @submission.reload.score }.to become 5

    f("#speed_grader_comment_textarea").send_keys("srsly")
    f('#add_a_comment button[type="submit"]').click
    expect { @submission.submission_comments.where(comment: "srsly").any? }.to become(true)
  end

  it "displays concluded students" do
    @teacher.preferences = { gradebook_settings: { @course.id => { "show_concluded_enrollments" => "true" } } }
    @teacher.save

    student_submission(username: "inactivestudent@example.com")
    en = @student.student_enrollments.first
    en.conclude

    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

    expect(ff("#students_selectmenu option")).to have_size 1 # just the one student
    expect(f("#enrollment_concluded_notice")).to include_text "Notice: Concluded Student"
  end

  context "when student names are hidden" do
    before do
      student_in_course(active_all: true, name: "student b")
      @student1 = @student
      student_in_course(active_all: true, name: "student a")
      @student2 = @student
      student_in_course(active_all: true, name: "student c")
      @student3 = @student

      @assignment.submission_types = "online_text_entry"
      @assignment.save!
    end

    it "sorts by submission date when eg_sort_by is submitted_at" do
      now = Time.zone.now.change(usec: 0)
      Timecop.freeze(3.minutes.ago(now)) do
        @submission1 = @assignment.submit_homework(@student1, submission_type: "online_text_entry", body: "student one")
      end
      Timecop.freeze(2.minutes.ago(now)) do
        @submission2 = @assignment.submit_homework(@student3, submission_type: "online_text_entry", body: "student three")
      end
      Timecop.freeze(1.minute.ago(now)) do
        @submission3 = @assignment.submit_homework(@student2, submission_type: "online_text_entry", body: "student two")
      end

      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

      Speedgrader.click_settings_link
      Speedgrader.click_options_link
      click_option("#eg_sort_by", "submitted_at", :value)
      Speedgrader.select_hide_student_names

      expect_new_page_load do
        Speedgrader.submit_settings_form
      end

      list_items = ff("#students_selectmenu option").pluck("value")
      expect(list_items).to contain_exactly(@student1.id.to_s, @student3.id.to_s, @student2.id.to_s)
    end

    it "sorts by submission status when eg_sort_by is submission_status" do
      @submission1 = @assignment.submit_homework(@student1, submission_type: "online_text_entry", body: "student one")
      @submission2 = @assignment.submit_homework(@student2, submission_type: "online_text_entry", body: "student three")
      @assignment.grade_student(@student2, grade: "90", grader: @teacher)

      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

      Speedgrader.click_settings_link
      Speedgrader.click_options_link
      click_option("#eg_sort_by", "submission_status", :value)
      Speedgrader.select_hide_student_names

      expect_new_page_load do
        Speedgrader.submit_settings_form
      end

      list_items = ff("#students_selectmenu option").pluck("value")

      expect(list_items).to contain_exactly(@student2.id.to_s, @student1.id.to_s, @student3.id.to_s)
    end
  end

  context "multiple enrollments" do
    before do
      student_in_course(active_all: true)
      @course_section = @course.course_sections.create!(name: "<h1>Other Section</h1>")
      @enrollment = @course.enroll_student(@student,
                                           enrollment_state: "active",
                                           section: @course_section,
                                           allow_multiple_enrollments: true)
    end

    it "does not duplicate students", priority: "1" do
      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

      expect(ff("#students_selectmenu > option")).to have_size 1
    end

    it "filters by section properly", priority: "1" do
      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

      sections = @course.course_sections
      section_options_text = f("#section-menu ul")[:textContent] # hidden
      expect(section_options_text).to include(@course_section.name)
      Speedgrader.visit_section(Speedgrader.section_with_id(sections[0].id))
      expect(ff("#students_selectmenu > option")).to have_size 1
      Speedgrader.visit_section(Speedgrader.section_with_id(sections[1].id))
      expect(ff("#students_selectmenu > option")).to have_size 1
    end
  end

  it "shows the first ungraded student with a submission", priority: "1" do
    s1, s2, s3 = n_students_in_course(3, course: @course)
    s1.update_attribute :name, "A"
    s2.update_attribute :name, "B"
    s3.update_attribute :name, "C"

    @assignment.grade_student s1, score: 10, grader: @teacher
    @assignment.find_or_create_submission(s2).tap do |submission|
      submission.student_entered_score = 5
    end.save!
    @assignment.submit_homework(s3, body: "Homework!?")

    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"
    wait_for_ajaximations

    expect(fj("#students_selectmenu option[value=#{s3.id}]")[:selected]).to be_truthy
  end

  it "allows the user to change sorting and hide student names", priority: "1" do
    student_submission(name: "student@example.com")

    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

    # sort by submission date
    Speedgrader.click_settings_link
    Speedgrader.click_options_link
    f('select#eg_sort_by option[value="submitted_at"]').click
    expect_new_page_load { fj(".ui-dialog-buttonset .ui-button:visible:last").click }
    expect(f("#combo_box_container .ui-selectmenu .ui-selectmenu-item-header")).to include_text @student.name

    # hide student names
    Speedgrader.click_settings_link
    Speedgrader.click_options_link
    f("#hide_student_names").click
    expect_new_page_load { fj(".ui-dialog-buttonset .ui-button:visible:last").click }
    expect(f("#combo_box_container .ui-selectmenu .ui-selectmenu-item-header")).to include_text "Student 1"

    # make sure it works a second time too
    Speedgrader.click_settings_link
    Speedgrader.click_options_link
    f('select#eg_sort_by option[value="alphabetically"]').click
    expect_new_page_load { fj(".ui-dialog-buttonset .ui-button:visible:last").click }
    expect(f("#combo_box_container .ui-selectmenu .ui-selectmenu-item-header")).to include_text "Student 1"

    # unselect the hide option
    Speedgrader.click_settings_link
    Speedgrader.click_options_link
    f("#hide_student_names").click
    expect_new_page_load { fj(".ui-dialog-buttonset .ui-button:visible:last").click }
    expect(f("#combo_box_container .ui-selectmenu .ui-selectmenu-item-header")).to include_text @student.name
  end

  context "student dropdown" do
    before do
      @section0 = @course.course_sections.create!(name: "Section0")
      @section1 = @course.course_sections.create!(name: "Section1")

      @student0 = User.create!(name: "Test Student 0")
      @student1 = User.create!(name: "Test Student 1")
      @course.enroll_student(@student0, section: @section0)
      @course.enroll_student(@student1, section: @section1)

      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"
    end

    it "show all sections menu item is present", priority: "2" do
      f("#students_selectmenu-button").click
      hover(f("#section-menu-link"))
      expect(f("#section-menu .ui-menu")).to include_text("Show All Sections")
    end

    it "lists all course sections", priority: "2" do
      f("#students_selectmenu-button").click
      hover(f("#section-menu-link"))
      expect(f("#section-menu .ui-menu")).to include_text(@section0.name)
      expect(f("#section-menu .ui-menu")).to include_text(@section1.name)
    end

    describe "discussion_checkpoints" do
      it "displays not_graded if SubAssignment needs_grading" do
        course_with_teacher_logged_in
        @course.account.enable_feature!(:discussion_checkpoints)
        @student = student_in_course(course: @course, active_all: true).user
        @topic = DiscussionTopic.create_graded_topic!(course: @course, title: "graded topic")
        @topic.create_checkpoints(reply_to_topic_points: 3, reply_to_entry_points: 7)

        @topic.reply_to_topic_checkpoint.submit_homework(@student, submission_type: "discussion_topic")
        @topic.assignment.grade_student(@student, grader: @teacher, score: 7, sub_assignment_tag: CheckpointLabels::REPLY_TO_ENTRY)

        get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@topic.assignment.id}"
        expect(f("#students_selectmenu-button")).to have_class("not_graded")
        expect(ff("#students_selectmenu option")).to have_size 1
      end

      it "updates graded status w/o reload for grade input", :ignore_js_errors do
        course_with_teacher_logged_in
        @course.account.enable_feature!(:discussion_checkpoints)
        @student = student_in_course(course: @course, active_all: true).user
        @topic = DiscussionTopic.create_graded_topic!(course: @course, title: "graded topic")
        @topic.create_checkpoints(reply_to_topic_points: 3, reply_to_entry_points: 7)

        @topic.reply_to_topic_checkpoint.submit_homework(@student, submission_type: "discussion_topic")
        @topic.assignment.grade_student(@student, grader: @teacher, score: 7, sub_assignment_tag: CheckpointLabels::REPLY_TO_ENTRY)

        get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@topic.assignment.id}"
        expect(f("#students_selectmenu-button")).to have_class("not_graded")
        expect(ff("#students_selectmenu option")).to have_size 1

        reply_to_topic_grade_input = ff("[data-testid='grade-input']")[0]
        reply_to_topic_grade_input.click
        set_value(reply_to_topic_grade_input, 1)
        reply_to_entry_grade_input = ff("[data-testid='grade-input']")[1]
        reply_to_entry_grade_input.click
        set_value(reply_to_entry_grade_input, 2)

        f(".ui-selectmenu-icon").click
        expect(f("#students_selectmenu-button")).to have_class("graded")

        reply_to_topic_select = f("[data-testid='reply_to_topic-checkpoint-status-select']")
        reply_to_topic_select.click
        fj("span[role='option']:contains('Excused')").click
      end

      it "updates graded status w/o reload for status input", :ignore_js_errors do
        course_with_teacher_logged_in
        @course.account.enable_feature!(:discussion_checkpoints)
        @student = student_in_course(course: @course, active_all: true).user
        @topic = DiscussionTopic.create_graded_topic!(course: @course, title: "graded topic")
        @topic.create_checkpoints(reply_to_topic_points: 3, reply_to_entry_points: 7)

        @topic.reply_to_topic_checkpoint.submit_homework(@student, submission_type: "discussion_topic")
        @topic.assignment.grade_student(@student, grader: @teacher, score: 7, sub_assignment_tag: CheckpointLabels::REPLY_TO_ENTRY)

        get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@topic.assignment.id}"
        expect(f("#students_selectmenu-button")).to have_class("not_graded")
        expect(ff("#students_selectmenu option")).to have_size 1

        reply_to_entry_grade_input = ff("[data-testid='grade-input']")[1]
        reply_to_entry_grade_input.click
        set_value(reply_to_entry_grade_input, 2)

        reply_to_topic_select = f("[data-testid='reply_to_topic-checkpoint-status-select']")
        reply_to_topic_select.click
        fj("span[role='option']:contains('Excused')").click

        f(".ui-selectmenu-icon").click
        expect(f("#students_selectmenu-button")).to have_class("graded")
      end
    end
  end

  it "includes the student view student for grading", priority: "1" do
    @course.student_view_student
    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

    expect(ff("#students_selectmenu option")).to have_size 1
  end

  it "marks the checkbox of students for graded assignments", priority: "1" do
    student_submission

    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

    expect(f("#students_selectmenu-button")).to have_class("not_graded")

    f("#grade_container input[type=text]").click
    set_value(f("#grade_container input[type=text]"), 1)
    f(".ui-selectmenu-icon").click
    expect(f("#students_selectmenu-button")).to have_class("graded")
  end

  context "Pass / Fail assignments" do
    it "displays correct options in the speedgrader dropdown", priority: "1" do
      course_with_teacher_logged_in
      course_with_student(course: @course, active_all: true)

      @assignment = @course.assignments.build
      @assignment.grading_type = "pass_fail"
      @assignment.publish

      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"
      select_box_values = ff("#grading-box-extended option").map(&:text)
      expect(select_box_values).to eql(["---", "Complete", "Incomplete", "Excused"])
    end
  end

  context "quizzes" do
    before(:once) do
      init_course_with_students
    end

    let_once(:quiz) { seed_quiz_with_submission }

    it "lets you enter in a float for a quiz question point value", priority: "1" do
      user_session(@teacher)
      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{quiz.assignment_id}"
      # In the left panel modify the grade to 0.5
      in_frame "speedgrader_iframe", ".quizzes-speedgrader" do
        points_input = ff("#questions .user_points input.question_input")
        driver.execute_script("$('#questions .user_points input.question_input').focus()")
        replace_content(points_input[0], "2")
        driver.execute_script("$('#questions .user_points input.question_input')[0].blur()")
        replace_content(points_input[1], ".5")
        driver.execute_script("$('#questions .user_points input.question_input')[1].blur()")
        replace_content(points_input[2], "1")
        driver.execute_script("$('#questions .user_points input.question_input')[2].blur()")
        f('.update_scores button[type="submit"]').click
        wait_for_ajaximations
      end
      # Switch to the right panel
      # Verify that the grade is .5
      wait_for_ajaximations
      expect { f("#grading-box-extended")["value"] }.to become("3.5")
      expect(f("#students_selectmenu-button")).to_not have_class("not_graded")
      expect(f("#students_selectmenu-button")).to have_class("graded")
    end
  end

  context "Crocodocable Submissions" do
    # set up course and users
    let(:test_course) { @course }
    let(:student)     { user_factory(active_all: true) }
    let!(:crocodoc_plugin) { PluginSetting.create! name: "crocodoc", settings: { api_key: "abc123" } }
    let!(:enroll_student) do
      test_course.enroll_user(student, "StudentEnrollment", enrollment_state: "active")
    end
    # create an assignment with online_upload type submission
    let!(:assignment) { test_course.assignments.create!(title: "Assignment A", submission_types: "online_text_entry,online_upload") }
    # submit to the assignment as a student twice, one with file and other with text
    let!(:file_attachment) { attachment_model(content_type: "application/pdf", context: student) }
    let!(:submit_with_attachment) do
      assignment.submit_homework(
        student,
        submission_type: "online_upload",
        attachments: [file_attachment]
      )
    end

    it "displays a flash warning banner when viewed in Firefox", priority: "2" do
      skip_if_chrome("This test applies to Firefox")
      skip_if_ie("This test applies to Firefox")
      # sometimes google docs is slow to load, which causes the flash
      # message to go away before `get` finishes. we're not testing
      # google docs here anyway, so ¯\_(ツ)_/¯
      Account.default.disable_service(:google_docs_previews)
      Account.default.save
      get "/courses/#{test_course.id}/gradebook/speed_grader?assignment_id=#{assignment.id}"
      assert_flash_notice_message "Warning: Crocodoc has limitations when used in Firefox. Comments will not always be saved."
    end
  end
end
