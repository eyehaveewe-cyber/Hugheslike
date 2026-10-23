# Grocery, bank and video-store atlas — v0.3

These are three connected authoring networks, not three isolated quest lists.
They use the existing GraphEdit editor, relationship filters, reference wires,
record inspector and nondestructive catalog merge. They are not playable shop
maps, working bank accounts or an executed social simulation.

## Open the new views

Open `project.godot` in Godot 4.7.2 and select Hughes Atlas, or press F5 for the
standalone atlas. The new views are Grocery store; Grocery: people and pressure;
Bank branch; Bank: records, permission and trust; Video store; Video: titles,
tapes and returns; Across all three stores; Ruth: wages, privacy and groceries;
and Hannah: the return and the record.

A previously saved graph deliberately remains unchanged on load. Use **Add
missing seed content…** once to bring in the new definitions, examples and views,
then Save. Existing authored labels, descriptions, metadata and layouts win.
The merge is undoable and idempotent. It is not a synchronization service: a
previously deleted bundled entry will be restored when explicitly requested.

Double-click a catalog item to focus it. One-hop views stay legible; two or
three hops reveal cross-store implications. The canvas still limits the number
of simultaneously visible nodes, while search and the inspector reach the
whole document. Scope filters separate definitions from fictional examples.
Turn on qualifier/reference wires when an event, holder, object or feeling is
part of an assertion. The holder lens is not a runtime privacy boundary.

## Grocery: households meet work

The grocery is separate from the earlier department store. Its spaces include
entrance/cart area, aisles, produce, cold case, checkout, service desk, stockroom,
loading doorway and staff room. Roles include manager, cashier, stocker, bagger,
receiver, driver, regular and customer. A worker can become a customer at the
end of a shift without losing their other relationships.

The network connects shopping lists, requested essentials, substitutions, posted
prices, till entries, coupons, receipts, deliveries, reserved cakes, parcel
custody, found wallets, break cover and closing. Backstock, shelf availability
and a product listing are different things. A cake can be physically present
but already promised to somebody else. The person sent to buy an item might
not know why it was requested or whether a substitute is suitable.

Scenes include a checkout shortfall, conflicting prices, an empty shelf, a
spill, two claims to the last item, unwelcome public help, an absent worker, a
wrong parcel, late cake pickup, a damaged return, a found wallet and an ordinary
purchase. All twelve have locations and possible responses in the graph.

Putting something back does not establish poverty. A public offer to pay may
be welcome, humiliating, self-promoting or simply declined. A regular can enjoy
being recognized and still dislike comments about their purchases. A last-minute
favor to a customer can make a worker miss their own appointment. None of these
outcomes is converted into a universal morality or popularity score.

## Bank: money, permission and trust are not one variable

The branch has public lobby, teller counter, writing table, waiting seats,
private office, records room and entrance. Teller, manager, records clerk,
customer, representative, business messenger, adult applicant and potential
guarantor have different kinds of responsibility.

The bank examples are fictional local arrangements, not statements of current
banking law or real account policies. There are no real account numbers,
credentials, funds, interest calculations, loan decisions or external services.

A request is distinct from its authorization, receipt, posting and fulfillment.
Holding an account differs from carrying its passbook. Delivering an envelope
differs from owning its contents. Being a relative or recognized customer does
not confer every permission. A deposit-only mandate is intentionally narrower
than withdrawal or information access. A pending payment does not establish
that its recipient lost a job, has no money elsewhere or acted dishonestly.

Scenes include pending availability, conflicting ledger/receipt information,
a missing local document, an overbroad authority request, closing-time queues,
a declined or delayed application, apparent favoritism, partial overhearing,
a misdelivered statement, a guarantee request, an ordinary visit and confusion
between messenger and owner. Records can remain contradictory while a review
is pending. Refusing a guarantee can preserve a financial boundary without
abolishing friendship.

## Video store: the title is not the tape

The store includes new releases, genre shelves, staff picks, rental counter,
after-hours return slot, processing shelf, reserved-copy shelf, staff room and
entrance. Roles include owner, clerk, return worker, registered renter, browser,
companion and entrusted return runner.

Film definitions, display cases, actual tape copies, reservations, rental
agreements, account permission, condition records, return events and processing
entries are separate. Two copies of the same work can have different states.
An empty display case is not an available playable copy. Borrowing the player
creates a separate obligation from borrowing the film. Seeing someone carry a
film does not establish their taste, who chose it or who watched it.

The invented catalogue includes Saturday at the Lake, The Midnight Courier,
A Dog Called Captain, The Brass Robot, The Glasshouse Garden and The Last Reunion
Bus. These are placeholders, not copied film scripts or external assets.

Scenes include a reserved last copy, a timely return logged late, the wrong tape
inside a case, disputed damage, a borrowed membership card, a format mismatch,
competing group preferences, teasing, a request for private rental history, a
threatened family evening, a quiet shared-interest discovery, browsing without
renting and a favor that conflicts with another promise. All thirteen have
locations and possible responses.

Recommendations can be thoughtful or mistaken without becoming persuasion
spells. Disagreeing about a film does not automatically damage friendship.
Browsers can leave without renting. Staff have their own tastes, rides, shifts
and private concerns rather than existing solely as menu operators.

## The new cast

All twelve new example people use biblical first names: Joseph, Ruth, Samuel,
Naomi, Deborah, Nathan, Esther, Ezra, Hannah, Caleb, Isaac and Lydia. These are
original fictional residents; the names do not assign biblical personalities
or religious roles. Existing authored people and stable identifiers were not
silently renamed. A later naming pass can change display labels without
breaking graph references.

Joseph manages the grocery; Ruth works the checkout and also shops there;
Samuel can cover a till and carry a business deposit. Naomi organizes household
errands. Deborah works the bank counter, Nathan manages the branch, and Esther
is a waiting customer. Ezra works the video counter and Lydia owns the store.
Hannah is a student returning a family tape; Caleb combines school, part-time
work and friendship. Isaac's delivery route can intersect several schedules.

## Two inspectable chains

### Ruth's wages-to-groceries afternoon

Ruth presents her wage cheque. Her authored account has pending availability.
Deborah sees the relevant record and explains it; Esther hears only a fragment.
Esther can hold an explicitly inferred, low-confidence belief that Ruth lost
her job. That does not remove Ruth's cashier role or create a job-loss fact.

At the grocery, Samuel sees Ruth put an item back but has not seen the private
bank note. Ruth can reduce the purchase, seek a private explanation, defer the
errand or consider an offered alternative. Her memory of the public pause is
not the same record as the financial transaction. Deborah's discretion can
matter to their relationship even if Deborah cannot remove the delay.

Search `character.ruth`, `account.ruth_bank_03`, `belief.esther_job_guess_03`
and `record.ruth_availability_03`. Compare the incident links rather than
assuming every character reachable through a graph path knows the same facts.

### Hannah's return and the clerk's record

Naomi holds the rental account. Hannah is entrusted to return a particular
copy, with return-only permission rather than blanket authority to rent more.
The store remains the copy's owner. In the illustrative timeline Hannah carries
it until tick 10, physically returns it at tick 10, and staff processing is at
tick 30. The agreed due boundary is tick 20. These are authored facts, not a
simulator advancing a clock.

A later processing entry is mistaken for the physical arrival time, producing
a fee claim and Ezra's initial late-return belief. Hannah's written account and
memory coexist with that notice. Caleb only saw a package; that does not give
him knowledge of its contents or who watched the film. A correction may change
the record without instantly removing embarrassment or resentment.

Search `character.hannah`, `prop.captain_copy_03`, `transaction.hannah_return_03`,
`transaction.ezra_processing_03` and `record.naomi_fee_notice_03`. The two
transactions deliberately do not share a stage: the physical return is complete
while administrative processing remains pending at the example snapshot.

## Cross-store implications and ordinary days

`routine.three_stop_errand` joins all three locations. A bank queue can change
which groceries are practical, whether a cake can be collected, or whether a
film return is delegated. None of the links demands that every visit escalate.
An ordinary round, private favor, quiet purchase and leaving without a rental
are represented. The next useful paper exercise is to vary one condition at a
time: ready cash, transport, staff attention, a deadline, or who hears an
explanation. Keep the protagonist's knowledge narrower than the author's view.

## Files and verification

The five additive pack files are in `addons/hughes_atlas/packs/`. The manifest
loads the common commerce vocabulary, grocery, bank, video and worked examples.
The v0.1 and v0.2 seed records remain unchanged and independently testable.

Run `python tools/atlas_commerce.py` to validate and report the combined library.
Run `python tools/atlas_commerce.py --export NEW_FILE.json` to create a portable
expanded graph. It refuses to overwrite an existing file. The current results
and remaining verification limits are recorded in `QA_COMMERCE.md`.

Conditions and notes are not executable business rules. No runtime inventory,
account arithmetic, autonomous queue, dialogue execution, interest simulation,
NPC knowledge enforcement, playable store map, XP or progression was added.
