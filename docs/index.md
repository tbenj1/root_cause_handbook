# The Root Cause Handbook

<div class="rch-hero" markdown>

<div class="rch-hero__content" markdown>

<span class="rch-eyebrow">IT troubleshooting guide</span>

## Find the cause. Prove the fix. Leave a clear trail.

This is a practical guide for working through IT issues from start to finish. Gather the right information, narrow down the issue, collect evidence, make controlled changes, confirm the fix, and leave notes that clearly explain what happened.

[Start the workflow](troubleshooting_workflow.md){ .md-button .md-button--primary }
[Open the checklist](checklist.md){ .md-button }

</div>

<div class="rch-hero__visual" aria-hidden="true">
  <img src="assets/images/root-cause-mark.svg" alt="">
  <div class="rch-signal rch-signal--one"><span>Observe</span></div>
  <div class="rch-signal rch-signal--two"><span>Isolate</span></div>
  <div class="rch-signal rch-signal--three"><span>Verify</span></div>
  <div class="rch-signal rch-signal--root"><span>Root cause</span></div>
</div>

</div>

!!! important "The main troubleshooting standard"

    **Do not guess when you can collect the information.** Change one meaningful thing at a time, test the result, and document what you found, what you changed, and what still needs to be done.

## Start troubleshooting

<div class="grid cards rch-stage-grid" markdown>

-   <span class="rch-stage-number">01</span> :material-account-search:{ .lg .middle } **Gather information**

    ---

    Find out who is affected, what is happening, where it happens, when it started, what changed, and how much it is affecting the business.

    [Gather the right details :material-arrow-right:](information_gathering.md)

-   <span class="rch-stage-number">02</span> :material-source-branch:{ .lg .middle } **Define the scope**

    ---

    Figure out whether the issue follows the user, device, application, location, network, account, or service.

    [Narrow down the issue :material-arrow-right:](defining_the_scope.md)

-   <span class="rch-stage-number">03</span> :material-tools:{ .lg .middle } **Investigate**

    ---

    Use comparison testing, Event Viewer, RMM data, PowerShell, command-line tools, internal documentation, and reliable technical sources.

    [Open the troubleshooting tools :material-arrow-right:](troubleshooting_tools.md)

-   <span class="rch-stage-number">04</span> :material-clipboard-check:{ .lg .middle } **Resolve and document**

    ---

    Make controlled changes, repeat the original test, confirm the expected result, document the cause when it is known, and leave useful notes.

    [Resolve the issue :material-arrow-right:](resolving_issues.md)

</div>

## Work through the issue in order

<div class="rch-principles" markdown>

<div class="rch-principle" markdown>

### :material-eye-outline: Look before changing anything

Reproduce the issue when possible. Document the exact message, time, device, user, location, and business impact before making changes.

</div>

<div class="rch-principle" markdown>

### :material-filter-variant: Narrow down the possibilities

Use comparison testing to rule things in or out. Each test should answer a specific question and help you decide what to check next.

</div>

<div class="rch-principle" markdown>

### :material-check-decagram-outline: Test what the user was trying to do

A command finishing successfully does not always mean the issue is fixed. Repeat the original action and confirm the expected result.

</div>

</div>

## Quick reference

<div class="grid cards rch-reference-grid" markdown>

-   :material-toolbox-outline:{ .lg .middle } **Troubleshooting Tools**

    ---

    PowerShell, Event Viewer, driver identification, Microsoft Update Catalog, MXToolbox, Purview Audit, and common Windows tools.

    [Open the tools section](troubleshooting_tools.md)

-   :material-alert-circle-check-outline:{ .lg .middle } **Escalation**

    ---

    Know when to stop, what information to include, and what the person taking over needs so they can continue without starting over.

    [Prepare a complete escalation](escalation.md)

-   :material-book-open-page-variant-outline:{ .lg .middle } **Documentation**

    ---

    Decide whether the fix belongs in the organization documentation, the shared knowledge base, or both.

    [Document the result](documentation.md)

-   :material-help-circle-outline:{ .lg .middle } **Setup and Help**

    ---

    Install, update, validate, start, stop, or repair the local handbook on Windows or macOS.

    [Open setup and help](help.md)

</div>

## Who this guide is for

This guide is for anyone who works through IT issues, including help desk, systems, network, application, cloud, and security professionals.

You are not expected to know every answer immediately. The goal is to clearly understand the issue, figure out how far it reaches, collect useful evidence, make safe changes, confirm the result, document what happened, and hand the issue off cleanly when someone else needs to take over.
