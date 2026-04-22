# INCREMENTAL DEVELOPMENT WORKFLOW (MANDATORY)

The agent MUST follow a strict step-by-step workflow.

## CORE RULE

* NEVER implement everything at once
* ALWAYS break work into small steps
* AFTER EACH STEP → STOP and WAIT for approval

---

## WORKFLOW PHASES

### PHASE 1 — ANALYSIS

Agent MUST:

* Identify the task
* Break it into steps
* Present plan as numbered steps

OUTPUT FORMAT:

STEP PLAN:

1. ...
2. ...
3. ...

Then STOP.

DO NOT WRITE CODE.

---

### PHASE 2 — STEP EXECUTION

Agent MUST:

* Execute ONLY ONE STEP at a time
* Output ONLY the changes for that step

OUTPUT FORMAT:

STEP X COMPLETE:

* What changed
* Which files modified
* Why (1 short sentence)

Then STOP.

WAIT FOR USER APPROVAL.

---

### PHASE 3 — APPROVAL GATE (CRITICAL)

Agent MUST NOT continue unless user explicitly says:

* "devam"
* "continue"
* "ok"

If no approval → STOP.

---

### PHASE 4 — VALIDATION

After each step, agent MUST:

* Check for:

  * syntax errors
  * edge cases
  * rule violations

If problem detected:
→ FIX before presenting step

---

## STRICT RULES

### NO BIG BANG IMPLEMENTATION

* Never generate full system in one response

### NO SILENT CHANGES

* Every change must be explicitly listed

### NO ASSUMPTIONS

* If something unclear → ASK instead of coding

### NO PARTIAL LOGIC

* Each step must be internally complete

---

## FAILURE CONDITIONS

If agent:

* skips approval step
* implements multiple steps at once
* does hidden changes

→ RESPONSE IS INVALID

---

## SPECIAL RULE — CRITICAL SYSTEMS

For:

* file operations
* export systems
* data writing

Agent MUST:

* isolate logic into separate steps:

  1. validation
  2. path handling
  3. write logic
  4. error handling

---

## GOAL

The system must behave like a senior engineer doing:

* controlled commits
* reviewable changes
* safe iteration

NOT like an AI dumping full code.
