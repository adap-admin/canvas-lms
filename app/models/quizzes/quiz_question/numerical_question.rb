# frozen_string_literal: true

#
# Copyright (C) 2012 - present Instructure, Inc.
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

class Quizzes::QuizQuestion::NumericalQuestion < Quizzes::QuizQuestion::Base
  class FlexRange
    def initialize(a, b)
      numbers = [BigDecimal(a.to_s), BigDecimal(b.to_s)].sort
      @range = numbers[0]..numbers[1]
    end

    delegate :cover?, to: :@range
  end

  def i18n_decimal(val)
    value = if val.is_a? String
              separator = I18n.t("number.format.separator")
              delimiter = I18n.t("number.format.delimiter")

              val.gsub(delimiter, "").gsub(separator, ".")
            else
              # If val is already a number, when we stringify it
              # we won't gsub the string as it will already be
              # formatted correctly
              val.to_s
            end

    # we use BigDecimal here to avoid rounding errors at the edge of the tolerance
    # e.g. in floating point, -11.7 with margin of 0.02 isn't inclusive of the answer -11.72
    begin
      BigDecimal(value)
    rescue ArgumentError
      BigDecimal("0.0")
    end
  end

  def answers
    @question_data[:answers].sort_by { |a| a[:weight] || CanvasSort::First }
  end

  def correct_answer_parts(user_answer)
    answer_text = user_answer.answer_text
    return nil if answer_text.nil?
    return false if answer_text.blank?

    answer_number = i18n_decimal(answer_text)

    match = answers.find do |answer|
      case answer[:numerical_answer_type]
      when "exact_answer"
        val = BigDecimal(answer[:exact].to_s.presence || "0.0")

        # calculate margin value using percentage
        if answer[:margin].to_s.ends_with?("%")
          answer[:margin] = (answer[:margin].to_f / 100.0 * val).abs
        end

        margin = BigDecimal(answer[:margin].to_s.presence || "0.0")
        min = val - margin
        max = val + margin
        answer_number.between?(min, max)
      when "precision_answer"
        submission = answer_number.split
        expected = BigDecimal(answer[:approximate].to_s.presence || "0.0").split
        precision = answer[:precision].to_i

        # compare sign
        submission[0] == expected[0] &&
          # compare significant digits truncated to precision
          submission[1][0, precision] == expected[1][0, precision] &&
          # base is always 10
          # compare exponent
          submission[3] == expected[3]
      else
        FlexRange.new(answer[:start], answer[:end]).cover?(answer_number)
      end
    end

    if match
      user_answer.answer_id = match[:id]
    end

    !!match
  end

  # TODO: remove once new stats is on for everybody
  def stats(responses)
    super

    @question_data.answers.each do |answer|
      answer[:text] = case answer[:numerical_answer_type]
                      when "exact_answer"
                        I18n.t("%{exact_value} +/- %{margin}", exact_value: answer[:exact], margin: answer[:margin])
                      when "precision_answer"
                        I18n.t("%{approximate_value} with precision %{precision}", approximate_value: answer[:approximate], precision: answer[:precision])
                      else
                        I18n.t("%{lower_bound} to %{upper_bound}", lower_bound: answer[:start], upper_bound: answer[:end])
                      end
    end

    @question_data
  end
end
