from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "docs" / "deliverable3_assets"
OUT = ROOT / "docs" / "ITMDA3-34_DELIVERABLE_3_FOLIO_SYSTEM_MODEL.docx"

NAVY = "0B2D63"
BLUE = "1B5CAA"
LIGHT_BLUE = "E7EEF8"
PALE = "F7F9FC"
GRAY = "666666"
BLACK = "111111"
WHITE = "FFFFFF"


def set_run(run, size=11, bold=False, color=BLACK, italic=False, font="Arial"):
    run.font.name = font
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), font)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), font)
    run.font.size = Pt(size)
    run.bold = bold
    run.italic = italic
    run.font.color.rgb = RGBColor.from_string(color)


def shade(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell(cell, text, bold=False, color=BLACK, size=9.2, align=None):
    cell.text = ""
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.0
    if align is not None:
        p.alignment = align
    r = p.add_run(str(text))
    set_run(r, size=size, bold=bold, color=color)


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def set_cell_width(cell, width_inches):
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_w = tc_pr.find(qn("w:tcW"))
    if tc_w is None:
        tc_w = OxmlElement("w:tcW")
        tc_pr.append(tc_w)
    tc_w.set(qn("w:w"), str(int(width_inches * 1440)))
    tc_w.set(qn("w:type"), "dxa")


def add_table(doc, headers, rows, widths, header_fill=NAVY, font_size=9.0):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for i, header in enumerate(headers):
        set_cell(table.rows[0].cells[i], header, True, WHITE, font_size)
        shade(table.rows[0].cells[i], header_fill)
        set_cell_width(table.rows[0].cells[i], widths[i])
    set_repeat_table_header(table.rows[0])
    for row_index, row_data in enumerate(rows):
        cells = table.add_row().cells
        for i, value in enumerate(row_data):
            set_cell(cells[i], value, False, BLACK, font_size)
            set_cell_width(cells[i], widths[i])
            if row_index % 2 == 0:
                shade(cells[i], PALE)
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(1)
    return table


def add_line(paragraph, color=BLUE, size=8):
    p_pr = paragraph._p.get_or_add_pPr()
    borders = p_pr.find(qn("w:pBdr"))
    if borders is None:
        borders = OxmlElement("w:pBdr")
        p_pr.append(borders)
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), str(size))
    bottom.set(qn("w:space"), "2")
    bottom.set(qn("w:color"), color)
    borders.append(bottom)


def add_page_field(paragraph):
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = " PAGE "
    separate = OxmlElement("w:fldChar")
    separate.set(qn("w:fldCharType"), "separate")
    text = OxmlElement("w:t")
    text.text = "1"
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, instr, separate, text, end])
    set_run(run, size=8.5, color=GRAY)


def configure_section(section, first=False):
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.65)
    section.left_margin = Inches(0.82)
    section.right_margin = Inches(0.82)
    section.header_distance = Inches(0.3)
    section.footer_distance = Inches(0.35)
    header = section.header.paragraphs[0]
    header.text = ""
    header.paragraph_format.space_after = Pt(3)
    r = header.add_run("EDUVOS | Faculty of Information Technology | ITMDA3-34")
    set_run(r, size=8.5, color=GRAY)
    add_line(header, BLUE, 6)
    footer = section.footer.paragraphs[0]
    footer.text = ""
    footer.paragraph_format.space_before = Pt(3)
    add_line(footer, BLUE, 6)
    r = footer.add_run("Model Development and System Design | 2026")
    set_run(r, size=8.5, color=GRAY)
    footer.add_run(" " * 34)
    r = footer.add_run("Page ")
    set_run(r, size=8.5, color=GRAY)
    add_page_field(footer)


def paragraph(doc, text="", bold_lead=None, align=None, after=6):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(after)
    p.paragraph_format.line_spacing = 1.08
    if align is not None:
        p.alignment = align
    if bold_lead and text.startswith(bold_lead):
        r = p.add_run(bold_lead)
        set_run(r, bold=True)
        r = p.add_run(text[len(bold_lead):])
        set_run(r)
    else:
        r = p.add_run(text)
        set_run(r)
    return p


def heading(doc, text, level=1):
    return doc.add_heading(text, level=level)


def bullet(doc, text):
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(text)
    set_run(r)
    return p


def number(doc, text):
    p = doc.add_paragraph(style="List Number")
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(text)
    set_run(r)
    return p


def caption(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(8)
    r = p.add_run(text)
    set_run(r, size=9, italic=True, color=GRAY)


def add_picture(doc, filename, width=6.55, caption_text=None):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(3)
    p.paragraph_format.space_after = Pt(2)
    shape = p.add_run().add_picture(str(ASSETS / filename), width=Inches(width))
    shape._inline.docPr.set("descr", caption_text or filename)
    shape._inline.docPr.set("title", caption_text or filename)
    if caption_text:
        caption(doc, caption_text)


def keep_with_next(paragraph):
    paragraph.paragraph_format.keep_with_next = True


def setup_styles(doc):
    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Arial"
    normal._element.rPr.rFonts.set(qn("w:ascii"), "Arial")
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Arial")
    normal.font.size = Pt(11)
    normal.font.color.rgb = RGBColor.from_string(BLACK)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.08
    for name, size, before, after in [
        ("Heading 1", 15, 13, 7),
        ("Heading 2", 12.5, 10, 5),
        ("Heading 3", 11, 7, 3),
    ]:
        style = styles[name]
        style.font.name = "Arial"
        style._element.rPr.rFonts.set(qn("w:ascii"), "Arial")
        style._element.rPr.rFonts.set(qn("w:hAnsi"), "Arial")
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = RGBColor.from_string(BLACK)
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True
    for name in ["List Bullet", "List Number"]:
        style = styles[name]
        style.font.name = "Arial"
        style.font.size = Pt(11)
        style.paragraph_format.left_indent = Inches(0.35)
        style.paragraph_format.first_line_indent = Inches(-0.18)
        style.paragraph_format.space_after = Pt(3)


def add_cover(doc):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(28)
    p.paragraph_format.space_after = Pt(20)
    r = p.add_run("Eduvos Assessment Coversheet")
    set_run(r, size=17, bold=True, color=NAVY)

    h = doc.add_paragraph()
    r = h.add_run("Academic Details")
    set_run(r, size=12.5, bold=True, color=NAVY)
    rows = [
        ["Campus:", "MIDRAND CAMPUS"],
        ["Faculty:", "INFORMATION AND TECHNOLOGY"],
        ["Module Code:", "ITMDA3-34"],
        ["Lecturer's Name:", "SIYANDA MBATHA"],
        ["Group (if applicable):", "GROUP 9"],
    ]
    table = doc.add_table(rows=0, cols=2)
    table.autofit = False
    for label, value in rows:
        cells = table.add_row().cells
        set_cell(cells[0], label, False, BLACK, 10.5)
        set_cell(cells[1], value, True, NAVY, 10.5)
        set_cell_width(cells[0], 1.7)
        set_cell_width(cells[1], 4.6)
        p = cells[1].paragraphs[0]
        add_line(p, BLACK, 4)

    h = doc.add_paragraph()
    h.paragraph_format.space_before = Pt(10)
    r = h.add_run("Assessment Details")
    set_run(r, size=12.5, bold=True, color=NAVY)
    details = [
        ["Assessment Type:", "FORMATIVE ASSESSMENT - DELIVERABLE 3"],
        ["Assignment/Brief Number:", ""],
        ["Due Date / Submission Date:", ""],
    ]
    table = doc.add_table(rows=0, cols=2)
    table.autofit = False
    for label, value in details:
        cells = table.add_row().cells
        set_cell(cells[0], label, False, BLACK, 10.5)
        set_cell(cells[1], value, True, NAVY, 10.5)
        set_cell_width(cells[0], 2.25)
        set_cell_width(cells[1], 4.05)
        add_line(cells[1].paragraphs[0], BLACK, 4)

    h = doc.add_paragraph()
    h.paragraph_format.space_before = Pt(10)
    h.paragraph_format.space_after = Pt(2)
    r = h.add_run("Student Details (Group, if applicable)")
    set_run(r, size=12, bold=True, color=NAVY)
    add_table(
        doc,
        ["#", "Full Name", "Student Number", "Contact Number", "% Participation", "Signature"],
        [
            ["1", "NSUKU MASWANGANYI", "EDUV4821574", "0662420011", "", "P.M"],
            ["2", "ANOTIDA DZINOTYIWEI", "EDUV4932003", "0662309680", "", "A.D"],
            ["3", "LONDIWE MAHLANGU", "36G7W75P7", "0678889911", "", "L.G.M"],
            ["4", "SURELY MODUPI", "EDUV4918966", "0698357263", "", "S.M"],
        ],
        [0.35, 1.45, 1.25, 1.2, 1.15, 0.9],
        font_size=8.5,
    )


def add_integrity_page(doc):
    doc.add_page_break()
    heading(doc, "Student Details (Individual, if applicable)", 2)
    add_table(doc, ["Field", "Details"], [["Student Full Name", ""], ["Student Number", ""]], [2.0, 4.3], font_size=10)
    heading(doc, "Academic Integrity", 2)
    paragraph(doc, "AI Disclosure Completed:     Yes [   ]     No [   ]")
    paragraph(doc, "Declaration:", bold_lead="Declaration:")
    paragraph(doc, "I declare that this assessment is my own original work except for source material explicitly acknowledged. I confirm that this work has not previously been submitted for assessment in any course. I acknowledge the institutional AI policy and confirm that AI tools have only been used as stipulated and documented in the AI Disclosure Appendix.")
    paragraph(doc, "Student Signature: ______________________________________________", after=14)
    paragraph(doc, "Date: __________________________", after=24)
    heading(doc, "Lecturer Use Only", 2)
    paragraph(doc, "Lecturer Comments:")
    paragraph(doc, "\n\n\n\n")
    paragraph(doc, "Marks Awarded (%): ____________________", after=14)
    paragraph(doc, "Lecturer Signature: ____________________        Date: ____________________")


def add_assessment_title(doc):
    doc.add_page_break()
    h = heading(doc, "Assessment", 1)
    h.paragraph_format.space_after = Pt(18)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(8)
    r = p.add_run("AI-Powered Student Financial Document Management Platform")
    set_run(r, size=17, bold=True, color=BLACK)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Deliverable 3: Proposed System Model and Solution Design")
    set_run(r, size=13, bold=True, color=NAVY)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(22)
    r = p.add_run("Folio - Secure Student Financial Document Workspace")
    set_run(r, size=11, italic=True, color=GRAY)
    paragraph(doc, "This deliverable translates the proposal and the existing Folio prototype into a structured model of the intended application. It defines the users, requirements, interactions, interface design, architecture, data model and dynamic processing behaviour that will guide development of the secure pilot.")
    paragraph(doc, "Planning boundary:", bold_lead="Planning boundary:")
    paragraph(doc, "The current repository is a prototype that uses simulated authentication, processing and seeded documents. Production behaviour described in this document is the intended secure-pilot model and must not be interpreted as already deployed or suitable for real student financial data.")


def add_topic_section(doc):
    heading(doc, "1. Topic Selection and Use Case Description", 1)
    heading(doc, "1.1 Selected Topic", 2)
    paragraph(doc, "The selected problem area is secure, AI-assisted management of student financial documents. Students who receive NSFAS support, institutional bursaries, scholarships or loans must manage award letters, fee statements, bank confirmations, appeal correspondence and renewal agreements. These records are frequently dispersed across email, messaging applications and device storage, making important conditions and deadlines difficult to find.")
    paragraph(doc, "Folio addresses this problem by providing one secure workspace where students can upload financial documents, organise them, receive evidence-linked summaries, search in natural language, ask grounded questions and track obligations derived from the source material.")
    heading(doc, "1.2 Users and Their Needs", 2)
    add_table(doc, ["User", "Primary needs", "Permitted scope"], [
        ["Funded student", "Fast retrieval, plain-language understanding, source evidence, deadline visibility, privacy controls and mobile access.", "Own documents and derived records."],
        ["Authorised financial-aid staff", "A limited, read-only view when the student requests assistance and grants explicit consent.", "Only the selected scope, purpose and time period."],
        ["Product or support operator", "Processing status, queue health, failure diagnostics, costs and service alerts.", "Operational telemetry; no unrestricted document-content access."],
    ], [1.35, 3.15, 1.85], font_size=8.8)
    heading(doc, "1.3 Intended Function, Purpose and Scope", 2)
    paragraph(doc, "The system is intended to help a student store, understand and act on financial paperwork without replacing the official Eduvos, NSFAS, bursary-provider or banking record. Folio is an informational assistance product. It does not make payments, submit forms automatically, alter funding records, contact institutions without instruction, or provide regulated financial, legal or academic advice.")
    heading(doc, "1.4 Underlying Design Principles", 2)
    bullet(doc, "Evidence first: every extracted fact or AI answer must link back to a page, passage or bounding box in an authorised source document.")
    bullet(doc, "Privacy by design: ownership, consent, retention and auditability are modelled from the beginning rather than added after development.")
    bullet(doc, "Human control: students confirm or correct suggested deadlines and may revoke sharing at any time.")
    bullet(doc, "Fail safely: uncertain extraction enters review, and grounded Q&A abstains when evidence is inadequate or contradictory.")


def add_requirements(doc):
    heading(doc, "2. Functional and Non-Functional Requirements", 1)
    heading(doc, "2.1 Functional Requirements", 2)
    rows = [
        ["FR-01", "Authenticate students through Folio-managed secure sign-in with MFA and protected session handling.", "Password hashing, MFA and secure sessions protect account and document access."],
        ["FR-02", "Accept PDF, DOCX, JPEG and PNG uploads through short-lived signed URLs.", "Private, validated and retryable document intake."],
        ["FR-03", "Track scanning, OCR, classification, extraction, indexing, ready, review and failed states.", "Visible progress and recoverable failure handling."],
        ["FR-04", "Present document type, summary, extracted entities, confidence and source evidence.", "Students can verify important values rather than trust unsupported output."],
        ["FR-05", "Search authorised titles, categories, extracted entities and OCR text.", "A target file or fact can be found quickly."],
        ["FR-06", "Answer questions using authorised retrieval, citations and explicit abstention.", "Every non-abstained answer is evidence grounded."],
        ["FR-07", "Create candidate deadlines that students can confirm, edit, dismiss or complete.", "Action tracking remains linked to the original evidence."],
        ["FR-08", "Support consent-based sharing, access history, export and deletion requests.", "Students can understand and control use of their information."],
        ["FR-09", "Apply a free monthly AI allowance and optional prepaid credits to chatbot questions.", "AI cost is bounded while upload, storage and search remain available."],
    ]
    add_table(doc, ["ID", "Requirement", "User value / acceptance indicator"], rows, [0.55, 3.55, 2.25], font_size=8.2)
    heading(doc, "2.2 Non-Functional Requirements", 2)
    rows = [
        ["Security", "TLS in transit, encrypted private storage, least privilege, signed URLs, secret management, dependency scanning and threat modelling."],
        ["Privacy", "Data minimisation, purpose limitation, explicit consent, retention controls, redacted logs and POPIA-aligned review."],
        ["Performance", "Responsive dashboard on a normal mobile connection and bounded retrieval time with visible loading feedback."],
        ["Usability", "Plain language, clear source evidence, understandable empty/error/retry states and responsive navigation."],
        ["Accessibility", "Keyboard support, semantic landmarks, visible focus, readable contrast, labelled controls and announced status changes."],
        ["Reliability", "Idempotent uploads and jobs, bounded retries, preserved metadata, safe failure states and dead-letter handling."],
        ["Maintainability", "Typed API contracts, Flyway migrations, automated tests, documented worker versions and reproducible setup."],
        ["Observability", "Health checks, queue metrics, processing latency, error rates, citation coverage and non-sensitive structured logs."],
    ]
    add_table(doc, ["Quality attribute", "Requirement"], rows, [1.35, 5.0], font_size=8.8)


def add_user_stories(doc):
    doc.add_page_break()
    heading(doc, "3. User Stories and Use Case Narratives", 1)
    paragraph(doc, "The narratives below cover the critical student, staff and operational interactions represented by the prototype and intended secure pilot.")
    stories = [
        ["US-01", "Student", "As a student, I want to sign in securely with MFA so that my financial documents are protected.", "A valid account and second factor reach the dashboard; invalid or expired sessions receive a generic unauthorised response."],
        ["US-02", "Student", "As a student, I want to upload a supported document so that it becomes searchable and understandable.", "The upload is private, validated, idempotent and shows processing progress."],
        ["US-03", "Student", "As a student, I want to verify an extracted amount or condition against the source page so that I can trust or correct it.", "Selecting a fact opens its evidence and confidence information."],
        ["US-04", "Student", "As a student, I want to search in natural language so that I can find a document without remembering its exact filename.", "Only authorised results are returned from title, category, entity and OCR text."],
        ["US-05", "Student", "As a student, I want to ask when my bursary renewal is due so that I can act without rereading several documents.", "The answer includes a valid citation or clearly abstains."],
        ["US-06", "Student", "As a student, I want to speak a question so that I can use the assistant when typing is inconvenient.", "Speech is converted to reviewable text and then uses the same grounded question flow."],
        ["US-07", "Student", "As a student, I want to confirm, edit, dismiss or complete a deadline so that the tracker reflects my obligations.", "The new status is saved, audited and does not erase source evidence."],
        ["US-08", "Student", "As a student, I want to share a selected summary for a limited purpose and period so that staff can assist safely.", "Scope, recipient, purpose, expiry and revocation are enforced on every request."],
        ["US-10", "Operator", "As an operator, I want to monitor failed processing jobs so that the service can recover without exposing document content.", "Queue status, retries and error classes are visible through operational telemetry."],
    ]
    add_table(doc, ["ID", "Actor", "Narrative", "Success condition"], stories, [0.55, 0.8, 3.25, 1.75], font_size=7.8)


def add_use_case(doc):
    heading(doc, "4. Use Case Diagram", 1)
    paragraph(doc, "The use case diagram defines the Folio system boundary and shows how each actor interacts with the proposed functions. The student owns the main journey. Staff access depends on active consent, while operators monitor system health rather than browsing student records.")
    add_picture(doc, "submitted-use-case.png", width=6.55, caption_text="Figure 1. Folio use case diagram showing actor responsibilities within the system boundary.")
    heading(doc, "4.1 Interpretation of the Use Case Diagram", 2)
    paragraph(doc, "System boundary: The large Folio workspace boundary separates functions implemented by the proposed application from external people. Every ellipse inside the boundary is therefore a service Folio must provide, while the three actors remain outside because they initiate interactions but are not part of the software itself.", bold_lead="System boundary:")
    paragraph(doc, "Student-centred ownership: The student is connected to secure sign-in, the document vault, grounded questions, deadlines, consent controls and personal audit history. This concentration of use cases reflects the core principle that the student owns the financial-document journey and must be able to inspect both source evidence and access history without relying on an administrator.", bold_lead="Student-centred ownership:")
    paragraph(doc, "Least-privilege staff access: Authorised financial-aid staff interact only with the consented student summary. They are intentionally not connected directly to the private document vault. In implementation, the staff request must be rejected unless the consent record matches the recipient, permitted scope, stated purpose and active time period.", bold_lead="Least-privilege staff access:")
    paragraph(doc, "Operational separation: The product or support operator monitors processing and service health rather than document content. This separation reduces privacy exposure: operational dashboards should reveal job identifiers, stages, timings and error classes, while sensitive source text remains hidden unless a separately authorised support process is invoked.", bold_lead="Operational separation:")


def add_mockups(doc):
    doc.add_page_break()
    heading(doc, "5. Wireframes and Screen Mockups", 1)
    paragraph(doc, "Mobile use is prioritised because students are likely to access funding information, upload paperwork and check urgent deadlines from a phone. The following mockups are rendered from the responsive Folio prototype at a 390 x 844 mobile viewport using synthetic data. The production system will retain this mobile-first hierarchy while replacing simulated state with protected API, storage, database and worker behaviour.")
    add_picture(doc, "navigation-flow.png", width=6.25, caption_text="Figure 2. Mobile-first screen navigation and user-flow model.")
    heading(doc, "5.1 Navigation Model Explained", 2)
    paragraph(doc, "The flow begins with Folio secure sign-in and MFA before exposing the dashboard. This is a security gate rather than a visual preference: no document metadata, extracted values or deadline information should be requested until the account credentials and second authentication factor have been verified.")
    paragraph(doc, "The dashboard leads into persistent mobile navigation with four stable destinations: Documents, Ask, Deadlines and Profile. Keeping these destinations continuously available lowers navigation depth on a phone and lets a student switch tasks without repeatedly returning through intermediate screens.")
    paragraph(doc, "The Document Vault leads to Document Detail because evidence review requires a specific source context. The detail screen combines preview, OCR output and evidence locations; it can then launch a grounded question or create a confirmed deadline. This preserves traceability because the resulting answer or action remains linked to the document that produced it.")

    mobile_pairs = [
        (
            "5.2 Secure Mobile Entry",
            [("mobile-01-signin.png", "Figure 3. Mobile sign-in"), ("mobile-02-mfa.png", "Figure 4. Mobile MFA verification")],
            "The entry flow requires Folio secure sign-in, MFA and privacy protection before the student reaches any document data.",
        ),
        (
            "5.3 Mobile Dashboard and Document Vault",
            [("mobile-03-dashboard.png", "Figure 5. Mobile dashboard"), ("mobile-04-documents.png", "Figure 6. Mobile document vault")],
            "The dashboard surfaces the most urgent summary information first. The vault then presents mobile-sized document cards with category, confidence, summary, date, pages and extraction access.",
        ),
        (
            "5.4 Mobile Ask AI and Deadline Tracker",
            [("mobile-05-ask-ai.png", "Figure 7. Mobile grounded assistant"), ("mobile-06-deadlines.png", "Figure 8. Mobile deadline tracker")],
            "The assistant makes credit usage and evidence grounding visible, while the deadline tracker keeps actions, due dates and source documents readable in a single-column phone layout.",
        ),
    ]
    for title, images, description in mobile_pairs:
        heading(doc, title, 2)
        table = doc.add_table(rows=1, cols=2)
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        table.autofit = False
        for cell, (image, label) in zip(table.rows[0].cells, images):
            cell.text = ""
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            shape = p.add_run().add_picture(str(ASSETS / image), width=Inches(2.95))
            shape._inline.docPr.set("descr", label)
            shape._inline.docPr.set("title", label)
            p2 = cell.add_paragraph()
            p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
            r = p2.add_run(label)
            set_run(r, size=8.5, italic=True, color=GRAY)
            set_cell_width(cell, 3.18)
        paragraph(doc, description)


def add_architecture(doc):
    doc.add_page_break()
    heading(doc, "6. Architecture Design", 1)
    paragraph(doc, "Folio uses a multi-tier, cloud-native architecture that separates client interfaces, application and security rules, private document storage, relational metadata and asynchronous intelligence services.")
    add_picture(doc, "architecture.png", width=6.55, caption_text="Figure 9. Proposed AWS-based Folio system architecture and trust boundaries.")
    heading(doc, "6.1 Architecture Diagram Explained", 2)
    paragraph(doc, "Layered request path: The web and Flutter clients communicate with a single secure API boundary over HTTPS and JSON. The clients are responsible for presentation and temporary interaction state, while Spring Boot remains authoritative for validation, identity mapping, ownership rules, consent checks and business decisions. This prevents a modified mobile client from bypassing server-side controls.", bold_lead="Layered request path:")
    paragraph(doc, "Identity and policy enforcement: Folio-managed authentication verifies the account credentials, second factor and secure session, but authentication alone does not grant access to every resource. The API must also check the user's role, document ownership and any active consent before calling application services or issuing a signed storage URL. These checks form the main trust boundary shown beside the API layer.", bold_lead="Identity and policy enforcement:")
    paragraph(doc, "Synchronous and asynchronous work: Short interactions such as listing documents, confirming a deadline or retrieving an authorised citation use the synchronous application-service path. Expensive work such as scanning, OCR, classification and extraction is placed on an asynchronous queue. This allows the mobile interface to show progress while workers retry safely without holding an HTTP request open.", bold_lead="Synchronous and asynchronous work:")
    paragraph(doc, "Data separation and provenance: PostgreSQL stores relationships, processing status, consent, audit records and derived evidence metadata, whereas source files remain in private object storage. The intelligence layer writes versioned results and provenance back to the data platform so an extracted fact can always be traced to its parser version, source document and page-level evidence.", bold_lead="Data separation and provenance:")
    heading(doc, "6.2 Core Components and Technologies", 2)
    rows = [
        ["Web client", "Next.js 14, React 18, TypeScript", "Responsive application shell, document views, upload progress, Ask AI, deadlines and privacy controls."],
        ["Mobile client", "Flutter and Dart", "Mobile-first access, biometric/passcode entry, voice input and the same protected API contracts."],
        ["API layer", "Spring Boot 3 and Java 21", "Spring Security, MFA-aware session validation, authorisation, business rules, signed URL issuance, consent, audit and credit metering."],
        ["Relational data", "PostgreSQL 16 and Flyway", "Identity mapping, ownership, metadata, extraction versions, deadlines, questions, consent and audit records."],
        ["Object storage", "Private S3-compatible bucket", "Encrypted source documents and safe derivatives accessed through short-lived signed URLs."],
        ["Processing worker", "Queue-backed adapters", "Malware scan, OCR, classification, extraction, chunking, indexing and bounded retry handling."],
        ["Grounded AI", "Scoped retrieval and model adapter", "Authorised retrieval, citation validation, confidence calculation and explicit abstention."],
        ["Hosting", "AWS and Docker parity", "Deployment through AWS services such as ECS or Fargate, RDS PostgreSQL, S3 and SQS with secret-backed configuration and reproducible local development."],
    ]
    add_table(doc, ["Component", "Technology", "Responsibility"], rows, [1.3, 1.8, 3.25], font_size=8.1)
    heading(doc, "6.3 Communication and Infrastructure Decisions", 2)
    number(doc, "Upload flow: client requests a signed URL, uploads directly to private object storage, confirms metadata, and triggers an asynchronous processing job.")
    number(doc, "Question flow: API verifies identity and credits, retrieves only authorised chunks, validates citations, and returns either an answer with evidence or an abstention.")
    number(doc, "Sharing flow: the student creates a limited consent record; every staff request is checked against scope, purpose, expiry and revocation before data is returned.")
    bullet(doc, "Direct object-storage uploads prevent large document bytes from consuming Spring Boot API memory.")
    bullet(doc, "PostgreSQL supports the relational integrity required for ownership, consent, deadlines and audit trails.")
    bullet(doc, "Derived extraction records are versioned and replaceable, while the original source remains authoritative.")


def add_data_design(doc):
    doc.add_page_break()
    heading(doc, "7. Data Design", 1)
    paragraph(doc, "A relational model is selected because Folio depends on strict ownership, consent, provenance and audit relationships. PostgreSQL stores metadata and derived records; original files remain in private object storage.")
    add_picture(doc, "erd.png", width=4.4, caption_text="Figure 10. Core Folio entity-relationship diagram grouped by data domain.")
    heading(doc, "7.1 Relationship Model Explained", 2)
    paragraph(doc, "Identity and governance: The users entity anchors ownership and accountability through a UUID primary key and a unique authentication subject. Consent records reference both the student granting access and the intended recipient, allowing one student to create multiple purpose-specific permissions. Audit events reference the actor who performed an action and record the affected target, creating an append-oriented security history.", bold_lead="Identity and governance:")
    paragraph(doc, "Versioned document processing: A document represents the stable logical item owned by a user, while document_versions records the output of a particular parser or processing run. Separating these entities means Folio can reprocess a source file without overwriting earlier results. extracted_entities then belongs to a specific version, so every amount, date or condition remains tied to the exact extraction that produced it.", bold_lead="Versioned document processing:")
    paragraph(doc, "Relational integrity: The foreign-key attributes shown in the model define the intended one-to-many paths: one user may own many documents; one document may have many processing versions; and one version may contain many extracted entities. The diagram groups the tables by domain to reduce line crossings, while the foreign keys and the entity-definition table below retain the full relationship meaning.", bold_lead="Relational integrity:")
    paragraph(doc, "Privacy by design: Document bytes are deliberately excluded from the relational model. The documents table stores only a private source key and lifecycle metadata, limiting database exposure. Consent and audit data are separated from extraction content so governance checks can be evaluated before the application retrieves document-derived information.", bold_lead="Privacy by design:")
    heading(doc, "7.2 Entity Definitions", 2)
    rows = [
        ["users", "Authentication subject, email, password hash, MFA state, role and creation time.", "Owns documents, questions, consents and audit events."],
        ["documents", "Owner, title, type, status, checksum, source key and retention date.", "Logical record for one private source document."],
        ["document_versions", "Parser version, summary, confidence and extraction time.", "Supports safe reprocessing and comparison."],
        ["extracted_entities", "Label, value, confidence, page, offsets and bounding box.", "Stores evidence-linked amounts, dates, conditions and actions."],
        ["deadlines", "Action, due time, timezone, status, source evidence and confirmation actor.", "Tracks candidate and student-confirmed obligations."],
        ["questions and citations", "Minimised question metadata, answer status, document, page and passage hash.", "Connects each grounded answer to authorised evidence."],
        ["consents", "Student, recipient, scope, purpose, expiry and revocation.", "Controls time-bound staff access."],
        ["audit_events", "Actor, action, target, metadata and timestamp.", "Append-only visibility into access and security events."],
    ]
    add_table(doc, ["Entity", "Key attributes", "Purpose / relationship"], rows, [1.35, 2.75, 2.25], font_size=8.1)
    doc.add_page_break()
    heading(doc, "7.3 Data Integrity and Privacy Rules", 2)
    bullet(doc, "The UUID user key is the stable internal identity; email is unique for sign-in but is not used as the relational primary key.")
    bullet(doc, "Foreign keys and ownership indexes enforce document-user relationships and support safe pagination.")
    bullet(doc, "Document bytes are not stored in PostgreSQL; only a private object key, checksum, size, type and retention metadata are stored.")
    bullet(doc, "Retrieval applies owner, consent, retention and deletion filters before keyword or vector search.")
    bullet(doc, "Deletion propagates to source objects, OCR chunks, embeddings, derived records and caches, subject to documented audit-retention exceptions.")


def add_dynamic_model(doc):
    heading(doc, "8. Dynamic Model, Key Parameters and Model Development", 1)
    paragraph(doc, "The selected dynamic model is an asynchronous state machine supported by events and bounded retry rules. This model is appropriate because a document passes through several long-running processing stages, may fail safely, may require review, and must remain observable to the student and operator.")
    add_picture(doc, "submitted-processing-activity.png", width=6.15, caption_text="Figure 11. Document-processing activity, validation decisions and outcome paths.")
    heading(doc, "8.1 Activity Diagram Explained", 2)
    paragraph(doc, "Early rejection and secure upload: File type and size are checked on the mobile client for immediate feedback, but the server must repeat security-sensitive validation. A valid file is uploaded through a short-lived signed URL, which avoids routing large document bytes through Spring Boot while still restricting the object key, operation and access period.", bold_lead="Early rejection and secure upload:")
    paragraph(doc, "Safety before intelligence: Scanning and content-signature checks occur before OCR or model-assisted extraction. The safe-and-readable decision prevents unsafe, corrupted or unsupported content from entering downstream services. A failed file retains enough metadata for support and retry analysis without being presented as successfully processed.", bold_lead="Safety before intelligence:")
    paragraph(doc, "Confidence as a control point: A technically successful extraction is not automatically treated as trustworthy. High-confidence output is stored as a versioned READY result, whereas uncertain output enters REVIEW_REQUIRED. This supports human verification and ensures the system does not silently present ambiguous dates, amounts or obligations as established facts.", bold_lead="Confidence as a control point:")
    paragraph(doc, "Unified user-visible outcome: Every branch converges on a visible status. READY exposes evidence-linked features, REVIEW_REQUIRED requests confirmation, FAILED offers a bounded retry or support path, and invalid input explains what the student must change. The convergence ensures that the interface never leaves a document in an unexplained loading state.", bold_lead="Unified user-visible outcome:")
    doc.add_page_break()
    heading(doc, "8.2 Document State Model", 2)
    rows = [
        ["UPLOADED", "Metadata exists and source upload is being confirmed.", "SCANNING or FAILED"],
        ["SCANNING", "Malware and content-signature checks are running.", "OCR or FAILED"],
        ["OCR", "Text is being extracted from digital or scanned pages.", "CLASSIFYING or FAILED"],
        ["CLASSIFYING", "Document type and confidence are calculated.", "EXTRACTING, REVIEW_REQUIRED or FAILED"],
        ["EXTRACTING", "Amounts, dates, conditions and actions are derived with provenance.", "INDEXING, REVIEW_REQUIRED or FAILED"],
        ["INDEXING", "Page-aware search chunks and retrieval indexes are created.", "READY or FAILED"],
        ["READY", "Document is available for evidence-linked search and questions.", "Reprocessing or deletion/retention workflow"],
        ["REVIEW_REQUIRED", "Confidence or evidence requires student or authorised human review.", "READY, reprocessing or FAILED"],
        ["FAILED", "A recoverable failure is visible while metadata remains intact.", "Bounded retry from the appropriate stage"],
    ]
    add_table(doc, ["State", "Meaning", "Allowed transition"], rows, [1.25, 3.55, 1.55], font_size=8.0)
    heading(doc, "8.3 Key Parameters", 2)
    rows = [
        ["Supported inputs", "PDF, DOCX, JPEG and PNG with a configurable maximum size.", "Covers common paperwork while bounding abuse and processing cost."],
        ["Confidence threshold", "Low-confidence extraction enters REVIEW_REQUIRED.", "Uncertain values are not presented as established facts."],
        ["Preview URL lifetime", "Short-lived signed access, proposed at approximately 15 minutes.", "Limits exposure when links are copied or cached."],
        ["Retry policy", "Idempotency key, bounded retries and dead-letter handling after exhaustion.", "Prevents duplicate records and supports operational recovery."],
        ["AI usage", "Free monthly allowance plus optional prepaid credits for chatbot questions.", "Balances student access with variable model cost."],
        ["Retention", "Per-document retention metadata and a verified deletion workflow.", "Supports purpose limitation and POPIA-aligned control."],
    ]
    add_table(doc, ["Parameter", "Proposed rule", "Reason"], rows, [1.3, 3.1, 1.95], font_size=8.2)
    heading(doc, "8.4 Model Development Sequence", 2)
    paragraph(doc, "Step 1: Establish identity, ownership, role and consent boundaries before connecting real documents.", bold_lead="Step 1:", after=3)
    paragraph(doc, "Step 2: Implement versioned metadata, signed storage access and the processing state machine.", bold_lead="Step 2:", after=3)
    paragraph(doc, "Step 3: Measure OCR and extraction quality by document type and route low-confidence output to review.", bold_lead="Step 3:", after=3)
    paragraph(doc, "Step 4: Add authorised retrieval, citation validation and abstention before enabling grounded Q&A.", bold_lead="Step 4:", after=3)
    paragraph(doc, "Step 5: Integrate confirmed deadlines, notifications, staff review, data rights and operational monitoring only after the secure foundation passes isolation tests.", bold_lead="Step 5:", after=3)


def add_conclusion(doc):
    doc.add_page_break()
    heading(doc, "9. Traceability to the Proposal and Conclusion", 1)
    rows = [
        ["Scattered student financial paperwork", "Secure vault, natural-language search, document processing and deadline tracking."],
        ["RAG should answer from the student's own files", "Authorised retrieval, citation validation, provenance and explicit abstention."],
        ["Sensitive data requires security from the start", "Secure sessions, MFA, signed URLs, encryption, least privilege, consent and append-only audit events."],
        ["Prototype uses synthetic or anonymised data", "Prototype and secure-pilot boundaries are identified throughout this deliverable."],
        ["AI usage must remain financially sustainable", "Credit metering applies to chatbot questions while upload and search remain available."],
        ["Folio is not an official financial system or advice engine", "Payments, submissions, record changes and regulated advice remain outside scope."],
    ]
    add_table(doc, ["Deliverable 1 proposal decision", "Modelled response in Deliverable 3"], rows, [2.75, 3.6], font_size=8.6)
    paragraph(doc, "Conclusion:", bold_lead="Conclusion:")
    paragraph(doc, "Folio is modelled as a secure, evidence-first document workspace in which the user interface, asynchronous processing pipeline, application architecture and relational data model support the same objective: students should be able to act on financial information quickly without losing visibility into its source or control over who may access it.")
    heading(doc, "References", 1)
    paragraph(doc, "Folio repository (2026). README.md, docs/PRD.md, docs/progress.md and frontend/src/components/FolioApp.tsx. Accessed 30 August 2026.")
    paragraph(doc, "ITMDA3-34 Deliverable 1 (2026). AI-Powered Student Financial Document Management Platform. Eduvos Faculty of Information Technology.")
    paragraph(doc, "Hevner, A. R., March, S. T., Park, J. and Ram, S. (2004). Design science in information systems research. MIS Quarterly, 28(1), 75-105.")
    paragraph(doc, "Republic of South Africa (2013). Protection of Personal Information Act, No. 4 of 2013.")


def build():
    doc = Document()
    setup_styles(doc)
    configure_section(doc.sections[0])
    add_cover(doc)
    add_integrity_page(doc)
    add_assessment_title(doc)
    add_topic_section(doc)
    add_requirements(doc)
    add_user_stories(doc)
    add_use_case(doc)
    add_mockups(doc)
    add_architecture(doc)
    add_data_design(doc)
    add_dynamic_model(doc)
    add_conclusion(doc)
    doc.core_properties.title = "ITMDA3-34 Deliverable 3 - Folio System Model"
    doc.core_properties.subject = "Proposed system model and solution design"
    doc.core_properties.author = "Group 9"
    doc.core_properties.keywords = "Folio, ITMDA3-34, Deliverable 3, UML, architecture, data design"
    doc.save(OUT)
    print(OUT)


if __name__ == "__main__":
    build()
