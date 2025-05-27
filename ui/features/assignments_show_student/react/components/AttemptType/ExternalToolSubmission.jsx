/*
 * Copyright (C) 2021 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import {func, number, string, shape, object} from 'prop-types'
import {useScope as createI18nScope} from '@canvas/i18n'
import React, {useEffect, useState} from 'react'

import iframeAllowances from '@canvas/external-apps/iframeAllowances'
import {Button} from '@instructure/ui-buttons'
import {ExternalTool as ExternalToolModel} from '@canvas/assignments/graphql/student/ExternalTool'
import {isSubmitted} from '../../helpers/SubmissionHelpers'
import {Text} from '@instructure/ui-text'
import {View} from '@instructure/ui-view'
import FormattedErrorMessage from '@canvas/assignments/react/FormattedErrorMessage'
import ToolLaunchIframe from '@canvas/external-tools/react/components/ToolLaunchIframe'

const I18n = createI18nScope('assignments_2_external_tool')
export const EXTERNAL_TOOL_ERROR_MESSAGE = I18n.t('Please launch the tool and select a resource')

// A generic component that shows an iframe for a given URL, used for both
// launching the LTI to select content and showing selected content
const ContentLaunchView = ({launchURL}) => (
  <ToolLaunchIframe
    allow={iframeAllowances()}
    data-testid="lti-launch-frame"
    src={launchURL}
    title={I18n.t('Tool content')}
  />
)

// A wrapper component for the above component, showing a specific URL
// (and possibly resource ID) via a course's retrieval endpoint
function SelectedContentView({url, resourceLinkLookupUuid}) {
  let launchURL = `/courses/${ENV.COURSE_ID}/external_tools/retrieve?assignment_id=${ENV.ASSIGNMENT_ID}&display=borderless`
  if (resourceLinkLookupUuid != null) {
    launchURL += `&resource_link_lookup_uuid=${resourceLinkLookupUuid}`
  }

  launchURL += `&url=${encodeURIComponent(url)}`

  return <ContentLaunchView launchURL={launchURL} />
}

function ExternalToolDraftView({
  createSubmissionDraft,
  onFileUploadRequested,
  submission,
  tool,
  submitButtonRef,
}) {
  const {submissionDraft} = submission
  const draftExistsForThisTool =
    submissionDraft?.externalTool?._id === tool._id && submissionDraft?.ltiLaunchUrl != null

  const [selectingItem, setSelectingItem] = useState(!draftExistsForThisTool)
  const [showErrorMessage, setShowErrorMessage] = useState(false)

  useEffect(() => {
    async function handleDeepLinking(e) {
      if (!['A2ExternalContentReady', 'LtiDeepLinkingResponse'].includes(e.data.subject)) {
        return
      }

      if (e.origin !== ENV.DEEP_LINKING_POST_MESSAGE_ORIGIN) {
        return
      }

      const contentItem = e.data?.content_items?.[0]
      if (contentItem == null) {
        return
      }

      clearErrors()

      if (contentItem['@type'] === 'FileItem' || contentItem.type === 'file') {
        // This is a file, so let's start the upload and redirect the user to
        // the file upload panel. Content type will be set on back-end, so we
        // set mediaType to an empty string here.
        onFileUploadRequested({files: [{...contentItem, mediaType: ''}]})
      } else {
        // This is a link, so we'll treat it as an LTI launch submission and
        // save a draft to that effect
        setSelectingItem(false)
        await createSubmissionDraft({
          variables: {
            activeSubmissionType: 'basic_lti_launch',
            attempt: submission.attempt || 1,
            externalToolId: tool._id,
            id: submission.id,
            ltiLaunchUrl: contentItem.url,
            resourceLinkLookupUuid: contentItem.lookup_uuid,
          },
        })
      }
    }

    window.addEventListener('message', handleDeepLinking)

    return () => {
      window.removeEventListener('message', handleDeepLinking)
    }
  }, [createSubmissionDraft, onFileUploadRequested, submission, tool])

  useEffect(() => {
    const handleClick = () => {
      if (!submissionDraft?.meetsBasicLtiLaunchCriteria) {
        const container = document.getElementById('external_tool_submission_container')
        container?.classList.add('error-outline')
        container?.setAttribute('aria-label', EXTERNAL_TOOL_ERROR_MESSAGE)
        container?.focus()
        setShowErrorMessage(true)
      }
    }

    submitButtonRef.current?.addEventListener('click', handleClick)

    return () => {
      submitButtonRef.current?.removeEventListener('click', handleClick)
    }
  }, [])

  const clearErrors = () => {
    const container = document.getElementById('external_tool_submission_container')
    container?.classList.remove('error-outline')
    container?.removeAttribute('aria-label')
    setShowErrorMessage(false)
  }

  const contentSelectionUrl = `/courses/${ENV.COURSE_ID}/external_tools/${tool._id}/resource_selection?launch_type=homework_submission&assignment_id=${ENV.ASSIGNMENT_ID}`

  return (
    <>
      <View id="external_tool_submission_container" as="div">
        {draftExistsForThisTool && !selectingItem ? (
          <View as="div" borderWidth="small" padding="small">
            <Text>{I18n.t('Website URL: %{url}', {url: submissionDraft.ltiLaunchUrl})}</Text>
            <br />
            <Button onClick={() => setSelectingItem(true)}>{I18n.t('Change')}</Button>

            <SelectedContentView
              url={submissionDraft.ltiLaunchUrl}
              resourceLinkLookupUuid={submissionDraft.resourceLinkLookupUuid}
            />
          </View>
        ) : (
          <ContentLaunchView launchURL={contentSelectionUrl} />
        )}
      </View>
      {showErrorMessage && (
        <View as="div" background="primary" padding="small 0 0 0">
          <FormattedErrorMessage message={EXTERNAL_TOOL_ERROR_MESSAGE} />
        </View>
      )}
    </>
  )
}

const ExternalToolSubmission = ({
  createSubmissionDraft,
  onFileUploadRequested,
  submission,
  tool,
  submitButtonRef,
}) =>
  isSubmitted(submission) ? (
    <SelectedContentView
      url={submission.url}
      resourceLinkLookupUuid={submission.resourceLinkLookupUuid}
    />
  ) : (
    <ExternalToolDraftView
      createSubmissionDraft={createSubmissionDraft}
      onFileUploadRequested={onFileUploadRequested}
      submission={submission}
      tool={tool}
      submitButtonRef={submitButtonRef}
    />
  )

export default ExternalToolSubmission

ExternalToolSubmission.propTypes = {
  createSubmissionDraft: func,
  onFileUploadRequested: func,
  submission: shape({
    attempt: number,
    id: string,
    url: string,
  }).isRequired,
  tool: ExternalToolModel.shape,
  submitButtonRef: object,
}

ExternalToolSubmission.defaultProps = {
  createSubmissionDraft: () => {},
  onFileUploadRequested: () => {},
}
