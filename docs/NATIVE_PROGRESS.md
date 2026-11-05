# Native render progress

The exporter uses the host's numeric progress and cancellation callbacks. The
small progress window presents encoder progress. Render does not wait on the
window or the app.

The owner retired the experimental VEGAS status-line text track. Its
historical test and rollback record live in the private investigation repository.
See [product status](STATUS.md) and [product architecture](product/TECH_ARCHITECTURE.md)
for active behavior and qualification.
