const fs = require("fs");
const {
  AlignmentType, BorderStyle, Document, Footer, HeadingLevel,
  Packer, Paragraph, ShadingType, Table, TableCell, TableRow,
  TextRun, WidthType
} = require("docx");

const root = "G:/Android/abap_casla_app_mobile";
const source = fs.readFileSync(root + "/docs/TECHNICAL_DOCUMENTATION.md", "utf8");
const lines = source.replace(/\r/g, "").split("\n");
const children = [];

function inline(value) {
  value = value.replaceAll(String.fromCharCode(96), "§");
  const runs = [];
  const pattern = /(\[[^\]]+\]\([^\)]+\)|§[^§]+§|\*\*[^*]+\*\*|\*[^*]+\*)/g;
  let last = 0;
  for (const match of value.matchAll(pattern)) {
    if (match.index > last) runs.push(new TextRun({ text: value.slice(last, match.index) }));
    const token = match[0];
    if (token.startsWith("[") && token.includes("](")) {
      runs.push(new TextRun({ text: token.slice(1, token.indexOf("](")), color: "1F4E79", underline: {} }));
    } else if (token.startsWith("§")) {
      runs.push(new TextRun({ text: token.slice(1, -1), font: "Consolas", color: "5B2C6F" }));
    } else if (token.startsWith("**")) {
      runs.push(new TextRun({ text: token.slice(2, -2), bold: true }));
    } else {
      runs.push(new TextRun({ text: token.slice(1, -1), italics: true }));
    }
    last = match.index + token.length;
  }
  if (last < value.length) runs.push(new TextRun({ text: value.slice(last) }));
  return runs.length ? runs : [new TextRun({ text: value })];
}

function codeParagraph(text) {
  return new Paragraph({
    children: [new TextRun({ text, font: "Consolas", size: 17, color: "1F2937" })],
    shading: { type: ShadingType.CLEAR, fill: "F3F4F6" },
    indent: { left: 260, right: 260 },
    spacing: { before: 0, after: 0, line: 240 }
  });
}

function cell(text, width, header) {
  return new TableCell({
    width: { size: width, type: WidthType.DXA },
    shading: header ? { type: ShadingType.CLEAR, fill: "1F4E79" } : undefined,
    margins: { top: 90, bottom: 90, left: 100, right: 100 },
    children: [new Paragraph({
      children: [new TextRun({ text: text.replace(/§/g, ""), bold: header, color: header ? "FFFFFF" : "1F2937", size: 17 })],
      spacing: { after: 0, line: 240 }
    })]
  });
}

function addTable(tableLines) {
  const rows = tableLines.map(line => line.trim().replace(/^\\|/, "").replace(/\\|$/, "").split("|").map(s => s.trim()));
  if (rows.length < 2) return;
  const header = rows[0];
  const body = rows.slice(2);
  const widths = header.map(() => Math.floor(9800 / header.length));
  children.push(new Table({
    width: { size: 9800, type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ children: header.map((v, i) => cell(v, widths[i], true)) }),
      ...body.map(row => new TableRow({ children: header.map((_, i) => cell(row[i] || "", widths[i], false)) }))
    ],
    borders: {
      top: { style: BorderStyle.SINGLE, size: 4, color: "D1D5DB" },
      bottom: { style: BorderStyle.SINGLE, size: 4, color: "D1D5DB" },
      left: { style: BorderStyle.SINGLE, size: 4, color: "D1D5DB" },
      right: { style: BorderStyle.SINGLE, size: 4, color: "D1D5DB" },
      insideHorizontal: { style: BorderStyle.SINGLE, size: 2, color: "E5E7EB" },
      insideVertical: { style: BorderStyle.SINGLE, size: 2, color: "E5E7EB" }
    }
  }));
  children.push(new Paragraph({ spacing: { after: 110 } }));
}

let inCode = false;
let codeLines = [];
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  if (line.startsWith(String.fromCharCode(96).repeat(3))) {
    if (inCode) {
      codeLines.forEach(code => children.push(codeParagraph(code)));
      children.push(new Paragraph({ spacing: { after: 120 } }));
      codeLines = [];
      inCode = false;
    } else {
      inCode = true;
    }
    continue;
  }
  if (inCode) {
    codeLines.push(line);
    continue;
  }
  if (!line.trim()) continue;
  if (line.startsWith("|")) {
    const table = [];
    while (i < lines.length && lines[i].trim().startsWith("|")) table.push(lines[i++]);
    i--;
    addTable(table);
    continue;
  }
  if (line.startsWith("# ")) {
    children.push(new Paragraph({ text: line.slice(2), style: "Title", spacing: { after: 180 }, keepNext: true }));
  } else if (line.startsWith("## ")) {
    children.push(new Paragraph({ children: inline(line.slice(3)), heading: HeadingLevel.HEADING_1, keepNext: true }));
  } else if (line.startsWith("### ")) {
    children.push(new Paragraph({ children: inline(line.slice(4)), heading: HeadingLevel.HEADING_2, keepNext: true }));
  } else if (/^\d+\. /.test(line)) {
    children.push(new Paragraph({ children: inline(line.replace(/^\d+\. /, "")), numbering: { reference: "ordered-list", level: 0 }, spacing: { after: 70, line: 260 } }));
  } else if (line.startsWith("- ")) {
    children.push(new Paragraph({ children: inline(line.slice(2)), numbering: { reference: "bullet-list", level: 0 }, spacing: { after: 70, line: 260 } }));
  } else {
    children.push(new Paragraph({ children: inline(line), spacing: { after: 130, line: 276 } }));
  }
}

const doc = new Document({
  creator: "CASLA Mobile Engineering",
  title: "CASLA Mobile Production Allocation Technical Documentation",
  description: "Technical documentation for the CASLA Mobile ABAP RAP backend",
  numbering: {
    config: [
      { reference: "bullet-list", levels: [{ level: 0, format: "bullet", text: "•", alignment: AlignmentType.LEFT }] },
      { reference: "ordered-list", levels: [{ level: 0, format: "decimal", text: "%1.", alignment: AlignmentType.LEFT }] }
    ]
  },
  styles: {
    default: { document: { run: { font: "Aptos", size: 20, color: "1F2937" }, paragraph: { spacing: { after: 120, line: 276 } } } },
    paragraphStyles: [
      { id: "Title", name: "Title", basedOn: "Normal", next: "Normal", run: { font: "Aptos Display", size: 34, bold: true, color: "000000" }, paragraph: { spacing: { after: 220 } } },
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", run: { font: "Aptos Display", size: 27, bold: true, color: "000000" }, paragraph: { spacing: { before: 260, after: 130 }, keepNext: true } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", run: { font: "Aptos", size: 23, bold: true, color: "000000" }, paragraph: { spacing: { before: 190, after: 100 }, keepNext: true } }
    ]
  },
  sections: [{
    properties: { page: { margin: { top: 850, right: 850, bottom: 850, left: 850 } } },
    children,
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "CASLA Mobile | Technical Documentation | Version 1.0", size: 16, color: "6B7280" })] })] }) }
  }]
});

Packer.toBuffer(doc).then(buffer => fs.writeFileSync(root + "/docs/CASLA_MOBILE_TECHNICAL_DOCUMENTATION.docx", buffer));
