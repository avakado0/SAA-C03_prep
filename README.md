# AWS SAA-C03 prep: drill your wrong answers

Notes, labs and a local quiz page built around one idea: **the questions you get wrong are the study material.** Not a braindump. No exam questions are reproduced here. Bring your own practice tests.

**Result:** passed SAA-C03 on October 22, 2026, after 222 hours and 59 minutes of study using these tactics.

Unofficial. Not affiliated with AWS, Udemy, Tutorials Dojo or anyone else.

## Repo map

| Path | What it is |
|---|---|
| `quiz/wrong_questions_quiz.html` | Local quiz page. Open it in a browser, no server needed. |
| `quiz/wrong_questions.json` | Sample data for the quiz: a handful of concept checks with answer, note, domain and service tags. Swap in your own. |
| `notes/glossary.md` | AWS terms I blanked on, in plain words. |
| `notes/networking.md`, `notes/ec2_ssh_keys.md` | Short topic notes. |
| `labs/` | Three hands-on labs: two-EC2 security-group puzzle, public EC2 app with Terraform, private EC2 reaching the internet through a NAT Gateway. |
| `practice_test_links.md` | Free practice-test sources, trusted vs unverified. |

## Strategy

Two tracks, running in parallel the whole time:

1. **Re-read your course notes** linearly, then re-skim weak sections.
2. **Take practice tests** from different sources, and review every one.

Flag three things during each test, even when you answered correctly:
- wrong answers
- a term you forgot or are shaky on
- an option you felt uneasy about

After each test, split the flags into two files:
- Scenario and reasoning misses (trap logic, service-comparison confusion) go to your own raw notes file (mine is `wrong_questions_raw.md`, kept out of this repo).
- Bare terms go to `glossary.md`.

Then drill the misses until you stop missing them. The quiz page does that.

## Tactics that paid off

- **Read the qualifier first.** "Fastest", "cheapest", "least operational effort", "most secure": two answers are often technically valid and the qualifier picks one.
- **Compare against your old wrong pick.** Every missed question stores the answer you chose. Test mode asks you to pick between the right answer and your own old mistake, so you learn the exact confusion you have.
- **Mix sources.** AWS's own questions are the best signal for real exam style. Third-party sets are harder in different ways.
- **Watch the clock.** One timed test ran 4 minutes over (2h14m for 65 questions). Pacing is a skill. Practice it.
- **Duplicates are signal.** The same miss across several sources goes to the top of the list.

## Score progression

Pass line is 72% on these sets.

| Source | Test 1 | Test 2 | Test 3 | Test 4 |
|---|---|---|---|---|
| Maarek practice exams | 53% | 48% | 60% | 70% |
| Tutorials Dojo | 69% | 66% | 73% | 70% |
| AWS official sample set (20 Qs) | 55% | | | |

Exam result: **passed on October 22, 2026**, after 222 hours and 59 minutes of study using these tactics.

## Topics I kept missing

- Security group rules that reference another security group as the source
- VPN and Direct Connect: VIF types, which side owns the VGW and which owns the customer gateway, non-transitive VPC peering
- S3 protection: Object Lock vs MFA Delete vs Versioning, and SSE-KMS vs SSE-C vs client-side encryption
- DataSync and FSx for NetApp ONTAP: supported locations and protocols
- CloudWatch vs CloudTrail vs Config vs GuardDuty: which service answers which question
- Auto Scaling: minimum capacity floors, termination policy order, spreading instances across AZs
- Global Accelerator vs CloudFront vs Route 53 routing policies
- Placement groups (spread: max 7 instances per AZ)

## Using the quiz page

Open `quiz/wrong_questions_quiz.html` in a browser.

- **Topic picker:** filter by AWS service or exam domain (Secure, Resilient, High-Performing, Cost).
- **Practice mode:** every question in the selection, reveal the answer when you want.
- **Test mode:** 10 random questions, answers shown only after the group is finished.

Question kinds: two-option (right answer vs your old mistake), multiple choice, and flashcards when no wrong pick was recorded.

This public copy ships with sample concept checks written from scratch. My own list of missed practice-test questions stays private, since those questions belong to their publishers.

### Make it yours

`quiz/wrong_questions.json` is a list of entries like:

```json
{
  "id": "s1-q3",
  "source": "Udemy Practice Exam 1",
  "q": "short question title",
  "correct": "the right answer",
  "myWrong": "the answer you picked, or null",
  "note": "why the right answer wins",
  "domains": ["Resilient"],
  "services": ["S3", "CloudTrail / Config"],
  "status": "confirmed"
}
```

Replace the entries, then paste the new JSON into the `const DATA = [...]` line near the top of the script block in the HTML. Only entries with `"status": "confirmed"` are shown.

## Resources

- [AWS SAA-C03 exam guide](https://aws.amazon.com/certification/certified-solutions-architect-associate/)
- AWS Skill Builder: free official practice question set
- [Tutorials Dojo](https://tutorialsdojo.com/) practice exams
- Stephane Maarek's SAA-C03 course and practice exams on Udemy

More free sources with trust notes are in `practice_test_links.md`.
