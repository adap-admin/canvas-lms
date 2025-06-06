# frozen_string_literal: true

#
# Copyright (C) 2014 - present Instructure, Inc.
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
#

require_relative "../../api_spec_helper"

describe Quizzes::QuizAssignmentOverridesController, type: :request do
  describe "[GET] /courses/:course_id/quizzes/assignment_overrides" do
    before do
      course_with_teacher(active_all: true)
      @quiz = @course.quizzes.create! title: "title"
      @quiz.workflow_state = "available"
      @quiz.build_assignment
      @quiz.publish!
      @quiz.reload
    end

    it "requires authorization" do
      user_factory(active_all: true) # not enrolled

      raw_api_call(:get,
                   "/api/v1/courses/#{@course.id}/quizzes/assignment_overrides",
                   { controller: "quizzes/quiz_assignment_overrides", action: "index", format: "json", course_id: @course.id.to_s },
                   { quiz_assignment_overrides: [{ quiz_ids: [@quiz.id] }] })

      expect(response).to have_http_status :forbidden
    end

    it "includes visible overrides" do
      due_at = 5.minutes.ago

      assignment_override_model({
                                  set: @course.default_section,
                                  quiz: @quiz,
                                  due_at:
                                })

      expect(@quiz.reload.assignment_overrides.count).to eq 1

      json = api_call(:get,
                      "/api/v1/courses/#{@course.id}/quizzes/assignment_overrides",
                      {
                        controller: "quizzes/quiz_assignment_overrides",
                        action: "index",
                        format: "json",
                        course_id: @course.id.to_s
                      },
                      {
                        quiz_assignment_overrides: [{
                          quiz_ids: [@quiz.id.to_s]
                        }]
                      })

      expect(json).to have_key("quiz_assignment_overrides")
      expect(json["quiz_assignment_overrides"].size).to eq 1
      json["quiz_assignment_overrides"][0].tap do |override|
        expect(override.keys.sort).to eq %w[all_dates due_dates quiz_id]
        expect(override["quiz_id"]).to eq @quiz.id
        expect(override["due_dates"].length).to eq 1
        expect(override["due_dates"][0]["due_at"]).to eq due_at.iso8601
      end
    end

    it "includes visible overrides if user can :read_as_admin" do
      due_at = 5.minutes.ago

      @course.account.role_overrides.create!({
                                               role: teacher_role,
                                               permission: "manage_assignments_add",
                                               enabled: false
                                             })

      assignment_override_model({
                                  set: @course.default_section,
                                  quiz: @quiz,
                                  due_at:
                                })

      expect(@quiz.reload.assignment_overrides.count).to eq 1

      json = api_call(:get,
                      "/api/v1/courses/#{@course.id}/quizzes/assignment_overrides",
                      {
                        controller: "quizzes/quiz_assignment_overrides",
                        action: "index",
                        format: "json",
                        course_id: @course.id.to_s
                      },
                      {
                        quiz_assignment_overrides: [{
                          quiz_ids: [@quiz.id.to_s]
                        }]
                      })

      expect(json).to have_key("quiz_assignment_overrides")
      expect(json["quiz_assignment_overrides"].size).to eq 1
      json["quiz_assignment_overrides"][0].tap do |override|
        expect(override.keys.sort).to eq %w[all_dates due_dates quiz_id]
        expect(override["quiz_id"]).to eq @quiz.id
        expect(override["due_dates"].length).to eq 1
        expect(override["due_dates"][0]["due_at"]).to eq due_at.iso8601
      end
    end

    context "differentiaiton tag overrides" do
      before do
        @course.account.enable_feature!(:assign_to_differentiation_tags)
        @course.account.tap do |a|
          a.settings[:allow_assign_to_differentiation_tags] = { value: true }
          a.save!
        end

        @student = course_with_student(course: @course).user

        @diff_tag_category = @course.group_categories.create!(name: "Differentiation Tags", non_collaborative: true)
        @diff_tag = @course.groups.create!(name: "Tag 1", group_category: @diff_tag_category, non_collaborative: true)
        @diff_tag.add_user(@student, "accepted")
      end

      it "includes differentiation tag overrides for student (and does not expose diff tag title)" do
        quiz_override = assignment_override_model({
                                                    set: @diff_tag,
                                                    quiz: @quiz,
                                                    due_at: 5.days.from_now
                                                  })

        expect(@quiz.reload.assignment_overrides.count).to eq 1

        json = api_call_as_user(@student,
                                :get,
                                "/api/v1/courses/#{@course.id}/quizzes/assignment_overrides",
                                {
                                  controller: "quizzes/quiz_assignment_overrides",
                                  action: "index",
                                  format: "json",
                                  course_id: @course.id.to_s
                                },
                                {
                                  quiz_assignment_overrides: [{
                                    quiz_ids: [@quiz.id.to_s]
                                  }]
                                })
        expect(json).to eq({
                             "quiz_assignment_overrides" => [
                               {
                                 "quiz_id" => @quiz.id,
                                 "due_dates" => [
                                   {
                                     "id" => quiz_override.id,
                                     "due_at" => quiz_override.due_at.iso8601,
                                     "unlock_at" => nil,
                                     "lock_at" => nil,
                                     "set_id" => @diff_tag.id,
                                     "set_type" => "Group",
                                   }
                                 ]
                               }
                             ]
                           })
      end
    end
  end

  describe "[GET] /courses/:course_id/new_quizzes/assignment_overrides" do
    before do
      course_with_teacher(active_all: true)
      @quiz = @course.assignments.create! submission_types: "external_tool"
      tool = @course.context_external_tools.create!(
        name: "Quizzes.Next",
        consumer_key: "test_key",
        shared_secret: "test_secret",
        tool_id: "Quizzes 2",
        url: "http://example.com/launch"
      )
      @quiz.external_tool_tag_attributes = { content: tool }
      @quiz.save!
    end

    it "requires authorization" do
      user_factory(active_all: true) # not enrolled

      raw_api_call(:get,
                   "/api/v1/courses/#{@course.id}/new_quizzes/assignment_overrides",
                   { controller: "quizzes/quiz_assignment_overrides", action: "new_quizzes", format: "json", course_id: @course.id.to_s },
                   { quiz_assignment_overrides: [{ quiz_ids: [@quiz.id] }] })

      expect(response).to have_http_status :forbidden
    end

    it "includes visible overrides" do
      due_at = 5.minutes.ago

      assignment_override_model({
                                  set: @course.default_section,
                                  quiz: @quiz,
                                  due_at:
                                })

      expect(@quiz.reload.assignment_overrides.count).to eq 1
      json = api_call(:get,
                      "/api/v1/courses/#{@course.id}/new_quizzes/assignment_overrides",
                      {
                        controller: "quizzes/quiz_assignment_overrides",
                        action: "new_quizzes",
                        format: "json",
                        course_id: @course.id.to_s
                      },
                      {
                        quiz_assignment_overrides: [{
                          quiz_ids: [@quiz.id.to_s]
                        }]
                      })

      expect(json).to have_key("quiz_assignment_overrides")
      expect(json["quiz_assignment_overrides"].size).to eq 1
      json["quiz_assignment_overrides"][0].tap do |override|
        expect(override.keys.sort).to eq %w[all_dates due_dates quiz_id]
        expect(override["quiz_id"]).to eq @quiz.id
        expect(override["due_dates"].length).to eq 1
        expect(override["due_dates"][0]["due_at"]).to eq due_at.iso8601
      end
    end
  end
end
