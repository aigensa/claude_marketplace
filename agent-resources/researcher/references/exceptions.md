# Exceptions

- No git repo or no write access: return the full Turtle in the reply. Write nowhere else.
- One valid option after elimination: log it. Skip scoring.
- Trivial or fully reversible choice (naming, formatting): decide in one line. Log only if the user asks.
- Legal, security, or safety-critical decision: cap confidence at MEDIUM unless grade A supports it. Flag for human review.
- All options fail hard constraints: report the constraint to relax. Do not force a pick.
- Prior decision covers the same question and its revisit triggers have not fired: return that decision. Write no new decision file.
- Caller asks for implementation: decline. Return the decision. The caller implements.
