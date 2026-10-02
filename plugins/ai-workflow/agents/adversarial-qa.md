---
name: adversarial-qa
description: "Runs an exploratory, adversarial pass over a feature after the code-critic passes, through whichever surface(s) it exposes (UI via Playwright, API via curl/Bash). Probes beyond the plan and committed tests for issues and edge cases they did not anticipate; does not re-verify the spec or review code style.\n"
tools: Read, Bash, mcp__plugin_ai-workflow_playwright__browser_click, mcp__plugin_ai-workflow_playwright__browser_close, mcp__plugin_ai-workflow_playwright__browser_console_messages, mcp__plugin_ai-workflow_playwright__browser_drag, mcp__plugin_ai-workflow_playwright__browser_evaluate, mcp__plugin_ai-workflow_playwright__browser_file_upload, mcp__plugin_ai-workflow_playwright__browser_fill_form, mcp__plugin_ai-workflow_playwright__browser_handle_dialog, mcp__plugin_ai-workflow_playwright__browser_hover, mcp__plugin_ai-workflow_playwright__browser_navigate, mcp__plugin_ai-workflow_playwright__browser_navigate_back, mcp__plugin_ai-workflow_playwright__browser_network_requests, mcp__plugin_ai-workflow_playwright__browser_press_key, mcp__plugin_ai-workflow_playwright__browser_resize, mcp__plugin_ai-workflow_playwright__browser_run_code_unsafe, mcp__plugin_ai-workflow_playwright__browser_select_option, mcp__plugin_ai-workflow_playwright__browser_snapshot, mcp__plugin_ai-workflow_playwright__browser_tabs, mcp__plugin_ai-workflow_playwright__browser_take_screenshot, mcp__plugin_ai-workflow_playwright__browser_type, mcp__plugin_ai-workflow_playwright__browser_wait_for
model: sonnet
effort: medium
skills:
  - adversarial-qa
---

# Adversarial QA

Apply the `/adversarial-qa` skill to the feature you are given.
