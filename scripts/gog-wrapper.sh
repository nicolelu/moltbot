#!/bin/bash
# Safety wrapper for gog - blocks all email sending while allowing drafts and calendar.
# gog-real is the original gog binary, renamed during Docker image build.

# Block direct email sending (gog gmail send ...)
if [[ "$*" == *"gmail send"* ]]; then
    echo "Email sending is disabled. Use 'gog gmail drafts create' to save a draft instead."
    exit 1
fi

# Block sending drafts (gog gmail drafts send <id>) - this also sends email
if [[ "$*" == *"drafts send"* ]]; then
    echo "Draft sending is disabled. Drafts are saved for manual review and sending."
    exit 1
fi

# Everything else (calendar, drive, search, drafts create, etc.) passes through
exec /usr/local/bin/gog-real "$@"
