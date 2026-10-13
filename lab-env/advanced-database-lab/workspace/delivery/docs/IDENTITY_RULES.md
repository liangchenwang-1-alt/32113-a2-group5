# Identity rule order and compatibility

Baseline: origin/main e8bc152 and W&C-identity-intergration 9b25245.
The upstream branch contains DATA_MODEL.md and an R3 patch against the old plural
source tables (customers, payers, digital_users). The delivery runner uses the
full singular source tables contributed by Qiushi. Original branch files remain
available and are not silently claimed to implement this adapted contract.

1. R1_CORE_ID anchors all 200 core profiles by their stable core IDs.
2. R2_DOB_CONTACT uses DOB plus normalized email OR normalized phone. Exactly one
   distinct target is required. Multiple targets remain ambiguous.
3. R3_NAME_EMAIL runs only when source DOB is missing and normalized name AND email
   identify exactly one core target. The name/email pair must also occur only once
   within that source system. A known conflicting DOB is never overridden.
4. A name alone never yields a customer_key. Blank contacts are null. A repeated
   name with no safe contact link is visible as ambiguous, not merged.

This adds a conservative DOB guard for the richer fixture. It is a local integration
decision for team review, not a claim that Sejin approved a new policy.
Full fixture: R1 200 matched; R2 375 matched; R3 0 matched; NONE 1 ambiguous and
1 unmatched. R3=0 is expected because the shipped matching records have DOB.
The rollback-only identity test verifies a positive R3 case separately.
Repeated builds are deterministic on this fixture; sequential surrogate keys are
not promised stable if the set of source customers changes.
