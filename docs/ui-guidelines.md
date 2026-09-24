# UI Guidelines

## Component Structure

- One component per file, named in PascalCase
- Component file and its `__tests__/` file share the same base name
- Keep components small — if a component exceeds ~150 lines, split it

## Styling

- CSS Modules or plain `.css` files co-located with the component
- No inline styles except for dynamic values (e.g., computed widths)
- Theme variables defined in `src/styles/theme.css`

## Accessibility

- All interactive elements must have accessible labels (`aria-label` or visible text)
- Use semantic HTML (`<button>`, `<input>`, `<ul>/<li>`) over `<div>` where appropriate
- Colour contrast must meet WCAG AA (4.5:1 for text)

## CloudWatch Dashboard UI Conventions

- Widget titles: sentence case, specific (e.g., "Request rate by status code")
- Y-axis units: match CloudWatch metric units (`Count`, `Milliseconds`, `Bytes`)
- Color scheme: red for errors/critical, yellow for warnings, green for healthy
- Default time range: last 3 hours
- Auto-refresh: 30 seconds for production dashboards
