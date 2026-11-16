import { createElement } from "react";
import Markdown, { defaultUrlTransform, type Components } from "react-markdown";
import type { Root } from "mdast";
import type { Citation } from "./models";

type MarkdownNode = {
  type: string;
  value?: string;
  url?: string;
  children?: MarkdownNode[];
};
function sourceMarkers() {
  return (tree: Root) => {
    const visit = (node: MarkdownNode) => {
      if (!node.children) return;
      node.children = node.children.flatMap((child) => {
        if (child.type !== "text" || !child.value?.includes("[SOURCE:")) {
          visit(child);
          return [child];
        }
        const replacements: MarkdownNode[] = [];
        let offset = 0;
        for (const marker of child.value.matchAll(/\[SOURCE:(\d+)\]/g)) {
          if (marker.index! > offset)
            replacements.push({
              type: "text",
              value: child.value.slice(offset, marker.index),
            });
          replacements.push({
            type: "link",
            url: `folio-source:${marker[1]}`,
            children: [{ type: "text", value: `Source ${marker[1]}` }],
          });
          offset = marker.index! + marker[0].length;
        }
        if (offset < child.value.length)
          replacements.push({ type: "text", value: child.value.slice(offset) });
        return replacements;
      });
    };
    visit(tree);
  };
}

export function citationByNumber(citations: Citation[], number: number) {
  return citations.find((citation) => citation.number === number);
}
export function AnswerMarkdown({
  text,
  citations = [],
  openSource,
}: {
  text: string;
  citations?: Citation[];
  openSource: (documentId: string, page: number | null) => void;
}) {
  const components: Components = {
    a: ({ href, children }) => {
      const marker = href?.match(/^folio-source:(\d+)$/);
      if (marker) {
        const citation = citationByNumber(citations, +marker[1]);
        if (!citation)
          return createElement(
            "span",
            {
              className: "ws-inline-source unavailable",
              title: "Source details unavailable",
            },
            children,
          );
        const label = `${citation.title}${citation.page ? `, page ${citation.page}` : ", page unavailable"}`;
        return createElement(
          "button",
          {
            type: "button",
            className: "ws-inline-source",
            title: label,
            "aria-label": `Open source: ${label}`,
            onClick: () => openSource(citation.documentId, citation.page),
          },
          children,
        );
      }
      return href
        ? createElement(
            "a",
            { href, target: "_blank", rel: "noopener noreferrer" },
            children,
          )
        : createElement("span", null, children);
    },
    img: () => null,
    h1: ({ children }) => createElement("h3", null, children),
    h2: ({ children }) => createElement("h3", null, children),
  };
  return createElement(Markdown, {
    children: text,
    skipHtml: true,
    disallowedElements: ["img"],
    remarkPlugins: [sourceMarkers],
    urlTransform: (url) =>
      /^folio-source:\d+$/.test(url) ? url : defaultUrlTransform(url),
    components,
  });
}
