from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.style import WD_STYLE_TYPE
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "ITDMA3-34_Deliverable_2_Folio_System_Model.docx"
ASSETS = ROOT / "docs" / "deliverable2_assets"
ASSETS.mkdir(parents=True, exist_ok=True)

NAVY = "102A43"; BLUE = "2E74B5"; TEAL = "0E7C74"; GOLD = "C97A2B"; INK = "243B53"; MUTED = "627D98"; PALE = "F4F7FA"; LINE = "CBD5E1"

def font(size=11, bold=False, color=INK, name="Calibri"):
    f = ImageFont.load_default()
    try:
        path = r"C:\Windows\Fonts\arial.ttf" if name == "Arial" else r"C:\Windows\Fonts\calibri.ttf"
        f = ImageFont.truetype(path, size)
        if bold:
            f = ImageFont.truetype(path.replace('.ttf','bd.ttf'), size)
    except Exception: pass
    return f

def diagram_canvas(w=1500, h=850):
    im = Image.new('RGB',(w,h),'white'); d=ImageDraw.Draw(im); return im,d

def box(d, xy, title, body='', fill='F4F7FA', outline=NAVY, title_color=NAVY, width=2):
    x1,y1,x2,y2=xy; d.rounded_rectangle(xy, radius=18, fill='#'+fill, outline='#'+outline, width=width)
    d.text((x1+18,y1+15), title, fill='#'+title_color, font=font(28,True))
    if body:
        yy=y1+57
        for line in body.split('\n'):
            d.text((x1+18,yy), line, fill='#'+INK, font=font(22)); yy+=30

def arrow(d, a, b, color=BLUE, width=5):
    d.line([a,b], fill='#'+color, width=width)
    import math
    ang=math.atan2(b[1]-a[1],b[0]-a[0]); size=18
    p1=(b[0]-size*math.cos(ang-0.45), b[1]-size*math.sin(ang-0.45)); p2=(b[0]-size*math.cos(ang+0.45), b[1]-size*math.sin(ang+0.45))
    d.polygon([b,p1,p2], fill='#'+color)

def save_diagrams():
    im,d=diagram_canvas(); d.text((40,28),'Folio use case model',fill='#'+NAVY,font=font(34,True))
    box(d,(60,160,400,300),'Student','Upload and manage documents\nAsk grounded questions\nReview deadlines\nControl privacy', 'E8F4F2', TEAL)
    box(d,(60,410,400,550),'Aid staff','Review only consented\nstudent summaries', 'FFF3E6', GOLD)
    box(d,(1080,160,1440,300),'Folio system','Secure document workspace\nwith evidence-bound AI', 'EAF1F8', BLUE)
    box(d,(1080,410,1440,550),'Operator','Monitor queues, errors,\nmetrics and incidents', 'F4F0F7', '6E5A7E')
    use=[('Upload document',(400,210),(1080,205)),('Ask AI question',(400,245),(1080,235)),('Track / complete deadline',(400,280),(1080,265)),('Share with consent',(400,455),(1080,460)),('Monitor processing',(1080,495),(400,495))]
    for label,a,b in use:
        arrow(d,a,b); d.text((620,a[1]-28),label,fill='#'+INK,font=font(22,True))
    im.save(ASSETS/'use_case_model.png')

    im,d=diagram_canvas(1600,900); d.text((40,28),'Folio high-level architecture',fill='#'+NAVY,font=font(34,True))
    box(d,(50,170,330,350),'Web client','Next.js / React / TypeScript\nResponsive dashboard', 'EAF1F8', BLUE)
    box(d,(50,500,330,680),'Mobile client','Flutter / Dart\nOffline-friendly UI', 'E8F4F2', TEAL)
    box(d,(560,250,980,530),'API layer','Spring Boot 3 / Java 21\nOIDC security + REST API\nAuthorisation + audit events', 'FFF3E6', GOLD)
    box(d,(1180,120,1530,300),'PostgreSQL','Users, documents, entities,\ndeadlines, consents, audits', 'EAF1F8', BLUE)
    box(d,(1180,390,1530,570),'Object storage','Private encrypted source files\nSigned upload / preview URLs', 'E8F4F2', TEAL)
    box(d,(1180,660,1530,840),'Worker + AI services','Scan / OCR / classify / extract\nChunk + retrieve + cite / abstain', 'F4F0F7', '6E5A7E')
    for a,b in [((330,260),(560,350)),((330,590),(560,430)),((980,330),(1180,220)),((980,390),(1180,480)),((980,470),(1180,750))]: arrow(d,a,b)
    d.text((380,195),'HTTPS / REST',fill='#'+MUTED,font=font(22,True)); d.text((1000,175),'JPA / SQL',fill='#'+MUTED,font=font(22,True)); d.text((1000,690),'Queue + signed object access',fill='#'+MUTED,font=font(22,True))
    im.save(ASSETS/'architecture.png')

    im,d=diagram_canvas(1700,950); d.text((40,28),'Folio relational data model',fill='#'+NAVY,font=font(34,True))
    box(d,(60,140,410,300),'users','id (PK)\noidc_subject, email, role', 'EAF1F8', BLUE)
    box(d,(620,110,1080,320),'documents','id (PK), owner_id (FK)\ntitle, type, status, checksum\nsource_key, created_at', 'E8F4F2', TEAL)
    box(d,(1260,110,1640,320),'document_versions','id (PK), document_id (FK)\nparser_version, summary\nconfidence, extracted_at', 'FFF3E6', GOLD)
    box(d,(620,470,1080,700),'entities','id (PK), version_id (FK)\nlabel, value, confidence\npage, offsets, bbox', 'F4F0F7', '6E5A7E')
    box(d,(60,560,410,780),'deadlines','id (PK), document_id (FK)\naction, due_at, status\nsource_evidence, confirmed_by', 'FFF3E6', GOLD)
    box(d,(1260,500,1640,740),'questions','id (PK), user_id (FK)\nquestion_hash, answer_status\ncreated_at, feedback', 'EAF1F8', BLUE)
    box(d,(1260,755,1640,935),'audit_events','id (PK), actor_id (FK)\naction, target_type, target_id\ncreated_at, metadata', 'E8F4F2', TEAL)
    for a,b in [((410,220),(620,220)),((1080,220),(1260,220)),((850,320),(850,470)),((620,580),(410,650)),((1260,600),(1080,600)),((1450,740),(1450,755))]: arrow(d,a,b)
    d.text((445,175),'owns',fill='#'+MUTED,font=font(22,True)); d.text((1100,175),'has versions',fill='#'+MUTED,font=font(22,True)); d.text((875,380),'contains',fill='#'+MUTED,font=font(22,True)); d.text((1100,555),'asks',fill='#'+MUTED,font=font(22,True))
    im.save(ASSETS/'erd.png')

    im,d=diagram_canvas(1700,1100); d.text((40,28),'Key screen wireframes',fill='#'+NAVY,font=font(34,True))
    screens=[('1. Sign in / MFA','Eduvos SSO\n[ email ]\n[ password ]\n[ Continue ]\nMFA code: [ _ _ _ _ _ _ ]'),('2. Dashboard','Folio    Search      Profile\n\n[ Documents 4 ] [ Actions 3 ]\n\nUrgent deadlines\n[ Submit proof of registration ]\n\nRecent documents'),('3. Documents','Documents        [ Upload ]\n[ Search documents........ ]\n\nFunding Award Letter  READY\nBursary Agreement     READY\nFee Statement          READY\n\nDetail: Preview | OCR | JSON'),('4. Ask AI','Ask AI     Credits 18/25\n\nSuggested: When is renewal due?\n\nStudent: When is my bursary renewal due?\nFolio: 02 Aug 2026 [Source p.3]\n[ Ask a question........ ]'),('5. Deadlines','Deadlines     [ Calendar ]\n\nHIGH  Submit proof of registration\n      12 Feb 2026   [ Complete ]\nMED   Renewal declaration\n      02 Aug 2026   [ Review ]'),('6. Security','Security & privacy\n\nMFA                 ON\nSharing             OFF\n\nAccess history\nDocument viewed ...\nAI query ...')]
    xs=[60,590,1120]; ys=[130,610]
    for i,(title,body) in enumerate(screens):
        x=xs[i%3]; y=ys[i//3]; d.rounded_rectangle((x,y,x+450,y+410),radius=16,fill='#F8FAFC',outline='#'+BLUE,width=3); d.text((x+18,y+18),title,fill='#'+NAVY,font=font(25,True)); yy=y+70
        for line in body.split('\n'):
            d.text((x+20,yy),line,fill='#'+INK,font=font(19)); yy+=43
    im.save(ASSETS/'wireframes.png')

def shade(cell, fill):
    tcPr=cell._tc.get_or_add_tcPr(); shd=OxmlElement('w:shd'); shd.set(qn('w:fill'),fill); tcPr.append(shd)

def set_cell_text(cell, text, bold=False, color=INK, size=9):
    cell.text=''; p=cell.paragraphs[0]; p.paragraph_format.space_after=Pt(0); r=p.add_run(text); r.bold=bold; r.font.size=Pt(size); r.font.name='Calibri'; r.font.color.rgb=RGBColor.from_string(color); cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER

def table(doc, headers, rows, widths=None):
    t=doc.add_table(rows=1, cols=len(headers)); t.alignment=WD_TABLE_ALIGNMENT.CENTER; t.style='Table Grid'
    for i,h in enumerate(headers): set_cell_text(t.rows[0].cells[i],h,True,'FFFFFF',9); shade(t.rows[0].cells[i],NAVY)
    for ridx,row in enumerate(rows):
        cells=t.add_row().cells
        for i,val in enumerate(row): set_cell_text(cells[i],str(val),False,INK,8.5); shade(cells[i], 'F7FAFC' if ridx%2==0 else 'FFFFFF')
    if widths:
        for row in t.rows:
            for i,w in enumerate(widths): row.cells[i].width=Inches(w)
    doc.add_paragraph().paragraph_format.space_after=Pt(2)
    return t

def bullet(doc, text):
    p=doc.add_paragraph(style='List Bullet'); p.add_run(text); return p

def num(doc, text):
    p=doc.add_paragraph(style='List Number'); p.add_run(text); return p

def caption(doc, text):
    p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before=Pt(2); p.paragraph_format.space_after=Pt(8); r=p.add_run(text); r.italic=True; r.font.size=Pt(9); r.font.color.rgb=RGBColor.from_string(MUTED)

def add_heading(doc, text, level=1):
    return doc.add_heading(text, level=level)

def add_para(doc, text, bold_lead=None):
    p=doc.add_paragraph()
    if bold_lead and text.startswith(bold_lead):
        p.add_run(bold_lead).bold=True; p.add_run(text[len(bold_lead):])
    else: p.add_run(text)
    return p

def build():
    save_diagrams(); doc=Document(); sec=doc.sections[0]; sec.top_margin=Inches(0.75); sec.bottom_margin=Inches(0.75); sec.left_margin=Inches(0.8); sec.right_margin=Inches(0.8)
    styles=doc.styles
    styles['Normal'].font.name='Calibri'; styles['Normal'].font.size=Pt(10.5); styles['Normal'].font.color.rgb=RGBColor.from_string(INK); styles['Normal'].paragraph_format.space_after=Pt(5); styles['Normal'].paragraph_format.line_spacing=1.1
    for name,size,color,before,after in [('Heading 1',16,BLUE,14,7),('Heading 2',13,BLUE,10,5),('Heading 3',11.5,NAVY,7,3)]:
        s=styles[name]; s.font.name='Calibri'; s.font.size=Pt(size); s.font.bold=True; s.font.color.rgb=RGBColor.from_string(color); s.paragraph_format.space_before=Pt(before); s.paragraph_format.space_after=Pt(after); s.paragraph_format.keep_with_next=True
    for name in ['List Bullet','List Number']:
        styles[name].font.name='Calibri'; styles[name].font.size=Pt(10.5); styles[name].paragraph_format.space_after=Pt(3); styles[name].paragraph_format.left_indent=Inches(0.3); styles[name].paragraph_format.first_line_indent=Inches(-0.15)
    header=sec.header.paragraphs[0]; header.text='Folio | ITMDA3-34 Deliverable 2'; header.runs[0].font.size=Pt(8); header.runs[0].font.color.rgb=RGBColor.from_string(MUTED)
    footer=sec.footer.paragraphs[0]; footer.alignment=WD_ALIGN_PARAGRAPH.RIGHT; footer.text='Folio system model | 2026'; footer.runs[0].font.size=Pt(8); footer.runs[0].font.color.rgb=RGBColor.from_string(MUTED)
    p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before=Pt(26); r=p.add_run('ITMDA3-34 | DELIVERABLE 2'); r.bold=True; r.font.size=Pt(12); r.font.color.rgb=RGBColor.from_string(TEAL)
    p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; r=p.add_run('Folio'); r.bold=True; r.font.size=Pt(32); r.font.color.rgb=RGBColor.from_string(NAVY)
    p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; r=p.add_run('Proposed System Model and Solution Design'); r.font.size=Pt(18); r.font.color.rgb=RGBColor.from_string(BLUE)
    p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_after=Pt(20); r=p.add_run('AI-powered student financial document management platform'); r.italic=True; r.font.size=Pt(11); r.font.color.rgb=RGBColor.from_string(MUTED)
    table(doc,['Document','Basis','Status'],[['Module','ITMDA3-34 Introduction Chapter','Submission deliverable'],['Project','Folio - Eduvos student finance workspace','Planning/model phase'],['Reference','ITMDA3-34 Deliverable 1 and repository PRD','Used as scope baseline']], [1.2,2.7,2.4])
    p=doc.add_paragraph(); p.paragraph_format.space_before=Pt(24); p.paragraph_format.space_after=Pt(6); r=p.add_run('Purpose of this deliverable'); r.bold=True; r.font.size=Pt(12); r.font.color.rgb=RGBColor.from_string(NAVY)
    add_para(doc,'This document translates the proposal into a structured model of how Folio should work from the user perspective and from the system perspective. It defines the selected topic, users, requirements, user stories, use cases, interface structure, architecture, and relational data design. The present repository contains a responsive prototype with simulated data; the secure pilot behaviours described here are the intended implementation model.')
    doc.add_page_break()
    add_heading(doc,'1. Topic selection and use case description',1)
    add_heading(doc,'1.1 Selected topic',2)
    add_para(doc,'The selected problem area is secure, AI-assisted management of student financial documents. Students who receive bursaries, scholarships, loans or institutional aid must manage award letters, fee statements, bank confirmations, appeals and renewal agreements. These records are commonly scattered across email, chat applications and device storage. Folio provides one secure workspace where the student can store documents, understand their contents, find evidence, and act on time-sensitive obligations.')
    add_heading(doc,'1.2 Users and needs',2)
    table(doc,['Actor','Needs','Access boundary'],[
        ['Funded student','Fast retrieval, plain-language explanation, source proof, deadlines, privacy and mobile access.','Own documents and own derived records.'],
        ['Authorised financial-aid staff','Review a limited student summary when the student grants explicit, time-bound consent.','Read-only, scoped and auditable access.'],
        ['Product/support operator','See queue health, failures, costs and incidents without reading document contents by default.','Operational telemetry only; no unrestricted student browsing.'],
    ],[1.3,3.2,2.0])
    add_heading(doc,'1.3 Purpose, scope and boundaries',2)
    add_para(doc,'Folio is an assistance product, not a replacement for an institution’s official financial system. It stores a student’s copies and produces evidence-linked assistance. It does not make payments, submit official forms, change funding records, or provide regulated financial, legal or academic advice. Prototype demonstrations use synthetic or anonymised data; real document bytes belong to the secure pilot boundary only after identity, storage, authorisation and audit controls are implemented.')
    add_heading(doc,'1.4 Core operating principle',2)
    add_para(doc,'Every extracted fact or AI answer must remain traceable to the original source document. Folio therefore treats the original file as the source of truth, stores provenance for derived values, filters retrieval by authorisation before generation, and abstains when evidence is missing, contradictory or too uncertain.')
    add_heading(doc,'2. Functional and non-functional requirements',1)
    add_heading(doc,'2.1 Functional requirements',2)
    table(doc,['ID','Requirement','User value / acceptance indicator'],[
        ['FR-01','Authenticate through Eduvos OIDC/SSO with MFA delegated to the identity provider.','Student reaches a protected workspace without Folio storing a separate password.'],
        ['FR-02','Upload PDF, DOCX, JPEG or PNG through a short-lived signed URL.','Upload is private, validated, resumable and does not duplicate on retry.'],
        ['FR-03','Process documents through scan, OCR, classification, extraction and indexing states.','Progress, failure and retry are visible; derived data has a parser version.'],
        ['FR-04','Display document category, summary, entities, confidence and page-level evidence.','Student can verify each important value against the source.'],
        ['FR-05','Search authorised titles, entities and OCR text.','Student finds a target document or fact quickly.'],
        ['FR-06','Answer questions with retrieval-grounded text and citations.','Every non-abstained answer has a verifiable source; insufficient evidence produces abstention.'],
        ['FR-07','Derive, confirm, edit, dismiss and complete deadline actions.','Each deadline retains source evidence and a clear status.'],
        ['FR-08','Provide privacy controls, consent-based sharing, export/deletion requests and audit history.','Student can see and control access to sensitive information.'],
        ['FR-09','Meter AI questions using a free monthly allowance and optional prepaid credits.','Costly AI usage is predictable while storage and document search remain available.'],
    ],[0.55,2.75,3.2])
    add_heading(doc,'2.2 Non-functional requirements',2)
    table(doc,['Quality','Requirement for Folio'],[
        ['Security','TLS, encrypted storage, least privilege, signed URLs, secret management, rate limiting and threat modelling.'],['Privacy','Purpose limitation, data minimisation, explicit consent, retention controls, POPIA review and redacted logs.'],['Performance','Fast dashboard on a normal mobile connection; bounded retrieval response with visible loading state.'],['Usability','Plain language, clear evidence, empty/error/retry/progress states, responsive layouts and low cognitive load.'],['Accessibility','Keyboard operation, semantic landmarks, focus indicators, readable contrast and screen-reader status announcements.'],['Reliability','Idempotent uploads and processing, retryable jobs, preserved metadata and dead-letter handling.'],['Maintainability','Typed API contracts, Flyway migrations, automated tests, documented worker versions and reproducible setup.'],['Observability','Health checks, queue metrics, processing latency, failure rates, citation coverage and non-sensitive structured logs.'],
    ],[1.3,5.2])
    add_heading(doc,'3. User stories and use case narratives',1)
    add_para(doc,'The following narratives cover the critical interactions represented by the prototype screens and the intended secure pilot. Each narrative expresses one user goal and a bounded system response.')
    stories=[
        ('US-01 - Sign in securely','As a student, I want to sign in with Eduvos SSO and MFA so that my financial documents are protected without creating another password.','The student starts authentication, the identity provider verifies the account and MFA, Folio maps the stable OIDC subject to a local user, and the dashboard opens. Failed or expired sessions return a generic unauthorised state.'),
        ('US-02 - Upload a document','As a student, I want to upload a financial document so that it becomes searchable and understandable.','The student selects a supported file. The client validates size/type, requests a signed URL, uploads directly to private object storage, and shows processing states. A retry is idempotent.'),
        ('US-03 - Verify extracted information','As a student, I want to inspect an extracted amount or condition alongside its source page so that I can trust or correct it.','The document detail view presents summary, entities, confidence and an evidence reference. Selecting an entity opens the relevant page/passage or shows an explicit missing-evidence state.'),
        ('US-04 - Search the vault','As a student, I want to search in plain language so that I can find the right document without remembering its exact filename.','The search service filters the student’s authorised document scope and matches title, category, entities and OCR text. Results show status and source type.'),
        ('US-05 - Ask a grounded question','As a student, I want to ask when a bursary renewal is due so that I can act without rereading several PDFs.','The API authorises the request, retrieves only allowed chunks, validates citations and returns an answer with source page references. If evidence is insufficient or contradictory, Folio abstains.'),
        ('US-06 - Use voice input','As a mobile student, I want to speak a question so that I can use the assistant quickly when typing is inconvenient.','The mobile/web client converts speech to text locally where supported, lets the student review it, and submits the same grounded question flow. No raw audio is required for the core model.'),
        ('US-07 - Manage a deadline','As a student, I want to confirm, edit, dismiss or complete a suggested deadline so that my action list reflects what I must do.','The student reviews source evidence, confirms the candidate action, changes details if needed, and marks it complete. The original extracted evidence is retained and the state change is audited.'),
        ('US-08 - Share with consent','As a student, I want to share a selected summary for a limited purpose and time so that staff can help without seeing everything.','The student chooses scope, recipient, purpose and expiry. Staff receives read-only access. Revocation immediately blocks future requests and remains in the audit history.'),
        ('US-09 - Review access history','As a student, I want to see who accessed my documents and when so that I can understand how my information is being used.','The security view shows upload, view, download, AI query, consent, export and deletion events with non-sensitive detail.'),
        ('US-10 - Recover a failed process','As a student, I want a clear retry option when processing fails so that I do not lose my document.','The document remains in the vault with a FAILED or REVIEW_REQUIRED status, an explanation that does not leak internal secrets, and a retry action. Operators can monitor the queue separately.'),
    ]
    for title,goal,flow in stories:
        add_heading(doc,title,2); add_para(doc,goal,bold_lead='As a'); add_para(doc,'Expected interaction: '+flow,bold_lead='Expected interaction:')
    add_heading(doc,'4. Use case diagram',1)
    doc.add_picture(str(ASSETS/'use_case_model.png'), width=Inches(6.5)); caption(doc,'Figure 1. Actors and principal Folio use cases.')
    add_para(doc,'The student is the primary actor and owns the core journey. Staff access is intentionally mediated by explicit consent, and operator access is limited to operational signals. The diagram separates the human roles from the Folio system boundary without implying that staff can browse student data by default.')
    add_heading(doc,'5. Wireframes and screen mockups',1)
    add_para(doc,'The wireframes below model six connected screens. The repository prototype already demonstrates the visual structure for the dashboard, documents, Ask AI, deadlines and security views; the production implementation will add real route protection, API state handling and source-authorised data.')
    doc.add_picture(str(ASSETS/'wireframes.png'), width=Inches(6.5)); caption(doc,'Figure 2. Key screen wireframes derived from the Folio prototype.')
    add_heading(doc,'5.1 User flow between screens',2)
    table(doc,['From','Action','To','Important state'],[
        ['Sign in / MFA','Successful identity verification','Dashboard','Authenticated session'],['Dashboard','Open documents or upload','Documents','Loading / empty / processing states'],['Documents','Select a record','Document detail','Preview, OCR and JSON evidence tabs'],['Dashboard or Documents','Open Ask AI','Ask AI','Credits, loading, cited answer or abstention'],['Dashboard','Select an action','Deadlines','Upcoming, overdue, complete or dismissed'],['Profile / navigation','Open Security','Security','MFA, sharing, audit and data-rights controls'],
    ],[1.25,2.05,1.25,1.95])
    add_heading(doc,'6. Architecture design',1)
    doc.add_picture(str(ASSETS/'architecture.png'), width=Inches(6.5)); caption(doc,'Figure 3. Proposed high-level technical architecture.')
    add_heading(doc,'6.1 Component responsibilities',2)
    table(doc,['Component','Technology','Responsibility'],[
        ['Web client','Next.js 14, React 18, TypeScript','Responsive shell, navigation, upload progress, document views, grounded chat, deadline and security interfaces.'],['Mobile client','Flutter / Dart','Mobile-first access, biometric/passcode entry where appropriate, voice input, cached UI state and the same API contracts.'],['API service','Spring Boot 3, Java 21','OIDC resource-server security, authorisation, REST contracts, business rules, signed URL issuance, audit events and credit metering.'],['Relational database','PostgreSQL 16 + Flyway','User identity mapping, metadata, derived extraction records, deadlines, questions, consent and append-only audit events.'],['Object storage','Private S3-compatible bucket','Encrypted source document bytes and safe rendered derivatives; never public by default.'],['Processing workers','Queue-backed worker adapters','Malware scan, OCR, classification, extraction, chunking, embeddings/indexing and retry/dead-letter handling.'],['AI retrieval service','Keyword/vector retrieval + model adapter','Scope-filtered retrieval, citation validation, confidence calculation and explicit abstention.'],['Hosting','Railway + Docker parity','Web, API and database deployment with local Docker Compose parity and secret-backed configuration.'],
    ],[1.35,1.65,3.5])
    add_heading(doc,'6.2 Main data and control flows',2)
    for s in ['Upload flow: client -> API for signed URL -> private object storage -> API completion callback -> processing queue -> worker -> PostgreSQL derived records -> client polling/event update.','Question flow: client -> API authentication and rate/credit check -> authorised retrieval filter -> model adapter -> citation validation -> answer and evidence response -> audit metadata.','Sharing flow: student selects scope -> API creates consent record -> scoped staff request -> authorisation check on every request -> access event -> student-visible revocation.']:
        num(doc,s)
    add_heading(doc,'6.3 Architectural principles and decisions',2)
    bullet(doc,'Security is enforced at every boundary: identity, API, storage, retrieval, sharing and audit. UI hiding alone is not an access-control mechanism.')
    bullet(doc,'Direct signed uploads avoid buffering large files through the JVM and keep document bytes out of the API process.')
    bullet(doc,'PostgreSQL is selected because ownership, consent, retention and audit relationships require relational integrity and transactional updates.')
    bullet(doc,'Derived extraction data is versioned and replaceable. The original source remains authoritative when parsers or models change.')
    bullet(doc,'The prototype may simulate authentication, processing and AI answers; the secure pilot must gate the same screens on real provider, storage, database and worker behaviour.')
    add_heading(doc,'7. Data design',1)
    doc.add_picture(str(ASSETS/'erd.png'), width=Inches(6.5)); caption(doc,'Figure 4. Proposed relational entity-relationship model.')
    add_heading(doc,'7.1 Entity definitions',2)
    table(doc,['Entity','Key attributes','Relationship / purpose'],[
        ['users','id, oidc_subject, email, role, created_at','One user owns many documents, questions, consents and audit events. OIDC subject is the stable external identity.'],['documents','id, owner_id, title, type, status, checksum, source_key, retention_until','Represents a logical document and its private source object.'],['document_versions','id, document_id, parser_version, summary, confidence','Allows reprocessing without erasing the previous source-derived record.'],['entities','id, version_id, label, value, confidence, page, offsets, bbox','Stores extracted amounts, dates, conditions and actions with provenance.'],['deadlines','id, document_id, action, due_at, timezone, status, source_evidence','Stores candidate and student-confirmed obligations.'],['questions','id, user_id, question_hash, answer_status, feedback','Stores minimised Q&A metadata for quality and abuse monitoring.'],['consents','id, student_id, recipient_id, scope, purpose, expires_at, revoked_at','Controls time-bound staff access.'],['audit_events','id, actor_id, action, target_type, target_id, created_at, metadata','Append-only record for access, sharing, AI, security and data-rights actions.'],
    ],[1.35,2.6,2.55])
    add_heading(doc,'7.2 Integrity, privacy and indexing rules',2)
    bullet(doc,'Foreign keys enforce ownership relationships; indexes support owner_id/status, document_id/version, due_at/status, and created_at audit queries.')
    bullet(doc,'Document bytes are never stored in PostgreSQL. Only a private object key, checksum, size, content type and retention metadata are stored.')
    bullet(doc,'Retrieval queries must include the authenticated user, tenant/ownership scope, active consent scope and retention/deletion filters before keyword or vector search.')
    bullet(doc,'Sensitive raw question text, document content, credentials and access tokens are excluded from ordinary logs. A minimised hash or classification is used when quality telemetry is required.')
    bullet(doc,'Deletion propagates to source objects, OCR chunks, embeddings, derived entities and caches, subject to documented audit-retention exceptions.')
    add_heading(doc,'8. Proposed dynamic model and state transitions',1)
    add_para(doc,'The selected dynamic model is a state-machine model for document processing combined with event-driven workflows. This is suitable because processing is asynchronous, has recoverable failure states, and must be observable to both the student and operator. It also supports idempotency and parser-versioned reprocessing.')
    table(doc,['State','Meaning','Allowed next states'],[
        ['UPLOADED','Metadata exists and source upload is being confirmed.','SCANNING, FAILED'],['SCANNING','Malware and content-signature checks are running.','OCR, FAILED'],['OCR','Text is being extracted from digital or scanned pages.','CLASSIFYING, FAILED'],['CLASSIFYING','Document type and confidence are determined.','EXTRACTING, REVIEW_REQUIRED, FAILED'],['EXTRACTING','Amounts, dates, conditions and actions are derived.','INDEXING, REVIEW_REQUIRED, FAILED'],['INDEXING','Search chunks and retrieval indexes are created.','READY, FAILED'],['READY','Student can use the document and its evidence.','EXTRACTING, deleted/retained'],['REVIEW_REQUIRED','Evidence or confidence needs human/student review.','READY, EXTRACTING, FAILED'],['FAILED','A recoverable processing failure is visible.','SCANNING, OCR, EXTRACTING, FAILED'],
    ],[1.35,3.0,2.15])
    add_heading(doc,'8.1 Processing parameters',2)
    table(doc,['Parameter','Proposed rule','Reason'],[
        ['File size/type','Configurable maximum; MVP PDF, DOCX, JPEG, PNG.','Limits abuse and processing cost while covering common student paperwork.'],['Confidence threshold','Low-confidence extraction routes to REVIEW_REQUIRED.','Prevents uncertain values being presented as facts.'],['Preview URL lifetime','Short-lived signed URL, e.g. 15 minutes.','Reduces exposure if a link is copied.'],['AI credits','Free monthly allowance plus optional prepaid credits.','Supports sustainable usage without locking storage/search behind credits.'],['Retry policy','Idempotency key, bounded retries, dead-letter after exhaustion.','Avoids duplicate records and makes failures recoverable.'],['Retention','Document and derived-data retention metadata; deletion workflow.','Supports purpose limitation and POPIA-aligned control.'],
    ],[1.4,2.9,2.2])
    add_heading(doc,'9. Traceability to Deliverable 1 and conclusion',1)
    add_para(doc,'Deliverable 1 established the problem, research aim, Eduvos student setting, RAG approach, security concern, credit-based sustainability model and deliberate project boundaries. This model carries each of those decisions into an implementable system design: the user roles express who benefits and who may access data; the requirements express the security and evidence guarantees; the screens express the intended student journey; the architecture expresses the cloud-native implementation; and the data model expresses how ownership, provenance, deadlines, consent and auditability will be preserved.')
    table(doc,['Deliverable 1 decision','Modelled response in this deliverable'],[
        ['Students struggle with scattered financial paperwork.','Secure vault, natural-language search, upload pipeline and deadline tracker.'],['RAG must answer from the student’s own files.','Authorised retrieval, citation validation and abstention are explicit requirements and flows.'],['Sensitive student data requires security from the start.','OIDC, signed URLs, encrypted storage, least privilege, consent and append-only audit events.'],['Prototype uses synthetic/anonymised data.','Prototype versus secure-pilot boundaries are stated throughout the model.'],['AI usage must be financially sustainable.','Credit metering applies to AI questions; storage and search remain available.'],['The platform is not an official financial system or advice engine.','Scope excludes payments, submissions, record changes and regulated advice.'],
    ],[2.6,3.9])
    add_para(doc,'Conclusion: Folio is modelled as a secure, evidence-first document workspace in which the interface, asynchronous processing pipeline and relational data model reinforce the same principle: students should be able to act on financial information quickly without losing visibility into where that information came from or who can access it.')
    add_heading(doc,'References',1)
    add_para(doc,'Folio repository. docs/PRD.md, docs/progress.md, README.md and frontend/src/components/FolioApp.tsx. Accessed 30 August 2026.')
    add_para(doc,'ITMDA3-34 Deliverable 1. AI-Powered Student Financial Document Management Platform. Eduvos Faculty of Information Technology, 2026.')
    add_para(doc,'Republic of South Africa (2013). Protection of Personal Information Act, No. 4 of 2013.')
    add_para(doc,'OpenID Foundation (2023). OpenID Connect Core 1.0 incorporating errata set 2.')
    add_para(doc,'Hevner, A. R., March, S. T., Park, J. and Ram, S. (2004). Design science in information systems research. MIS Quarterly, 28(1), 75-105.')
    doc.core_properties.title='Folio - ITMDA3-34 Deliverable 2'; doc.core_properties.subject='Proposed system model and solution design'; doc.core_properties.author='Folio Group 9'
    doc.save(OUT); print(OUT)

if __name__=='__main__': build()
