/*
 * Copyright (C) 2015 - present Instructure, Inc.
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

import {find} from 'lodash'
import React from 'react'
import {createRoot} from 'react-dom/client'
import MoveDialog from './react/components/MoveDialog'
import filesEnv from '@canvas/files/react/modules/filesEnv'
import $ from 'jquery'

function openMoveDialog(
  thingsToMove,
  {contextType, contextId, returnFocusTo, clearSelectedItems, onMove},
) {
  const rootFolderToShow = find(filesEnv.rootFolders, folder => {
    return (
      `${folder.get('context_type').toLowerCase()}s` === contextType &&
      String(folder.get('context_id')) === String(contextId)
    )
  })

  const $moveDialog = $('<div>').appendTo(document.body)
  const root = createRoot($moveDialog[0])

  const handleClose = () => {
    root.unmount()
    $moveDialog.remove()
    $(returnFocusTo).focus()
  }

  const handleMove = models => {
    onMove(models) && clearSelectedItems()
  }

  root.render(
    <MoveDialog
      thingsToMove={thingsToMove}
      rootFoldersToShow={filesEnv.showingAllContexts ? filesEnv.rootFolders : [rootFolderToShow]}
      onClose={handleClose}
      onMove={handleMove}
    />,
  )
}

export default openMoveDialog
