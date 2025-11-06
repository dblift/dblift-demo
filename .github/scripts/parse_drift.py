#!/usr/bin/env python3
"""Parse dblift drift output and create a detailed summary."""

import sys
import re
from pathlib import Path

def parse_drift_output(file_path: str) -> str:
    """Parse drift output and return markdown summary."""
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    summary = []
    current_table = None
    current_column = None
    
    # Extract error count
    error_count = "0"
    for line in lines:
        match = re.search(r'Critical differences found: (\d+)', line)
        if match:
            error_count = match.group(1)
            break
    
    if error_count == "0":
        return "## 🔍 Schema Drift Detection\n\n✅ **No drift detected** - Database schema matches migrations\n"
    
    summary.append("## 🔍 Schema Drift Detection\n")
    summary.append(f"⚠️ **Drift detected:** {error_count} difference(s) found\n")
    
    # Parse table differences
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Table modifications
        table_match = re.search(r"Table '([^']+)' modifications: missing_cols=\[([^\]]*)\], extra_cols=\[([^\]]*)\], modified_cols=\[([^\]]*)\], missing_constraints=\[([^\]]*)\], extra_constraints=\[([^\]]*)\]", line)
        if table_match:
            table_name = table_match.group(1)
            missing_cols = table_match.group(2)
            extra_cols = table_match.group(3)
            modified_cols = table_match.group(4)
            missing_constraints = table_match.group(5)
            extra_constraints = table_match.group(6)
            
            summary.append(f"\n### Table: `{table_name}`\n")
            
            if missing_cols:
                summary.append(f"- ❌ **Missing columns:** {missing_cols.replace(\"'\", '')}\n")
            if extra_cols:
                summary.append(f"- ➕ **Extra columns:** {extra_cols.replace(\"'\", '')}\n")
            if modified_cols:
                summary.append(f"- ⚠️ **Modified columns:** {modified_cols.replace(\"'\", '')}\n")
            if extra_constraints:
                summary.append(f"- 🔗 **Extra constraints:** {extra_constraints.replace(\"'\", '')}\n")
            
            # Look ahead for column details
            i += 1
            while i < len(lines):
                next_line = lines[i].strip()
                
                # Modified column name
                col_match = re.search(r"Modified column '([^']+)':", next_line)
                if col_match:
                    col_name = col_match.group(1)
                    summary.append(f"  - **{col_name}**:\n")
                    i += 1
                    continue
                
                # Data type difference
                if 'data_type:' in next_line:
                    dt_match = re.search(r'data_type: \((.+)\)', next_line)
                    if dt_match:
                        summary.append(f"    - Data type: `{dt_match.group(1)}`\n")
                    i += 1
                    continue
                
                # Default difference
                if 'default:' in next_line:
                    def_match = re.search(r'default: \((.+)\)', next_line)
                    if def_match:
                        summary.append(f"    - Default: `{def_match.group(1)}`\n")
                    i += 1
                    continue
                
                # Extra constraints details
                if 'Extra constraints details:' in next_line:
                    i += 1
                    continue
                
                # End of this table's details
                if next_line.startswith("INFO:") and ("Table '" in next_line or "Schema diff summary" in next_line or "Index '" in next_line):
                    break
                
                i += 1
        
        i += 1
    
    # Extract index differences
    index_names = []
    for line in lines:
        index_match = re.search(r"Index '([^']+)' has differences:", line)
        if index_match:
            index_names.append(index_match.group(1))
    
    if index_names:
        summary.append(f"\n### Index Differences ({len(index_names)})\n")
        summary.append("```\n")
        summary.append("\n".join(index_names[:10]))
        summary.append("\n```\n")
    
    # Extract trigger differences
    for line in lines:
        if "Trigger diff summary" in line:
            trigger_match = re.search(r'modified: \[([^\]]+)\]', line)
            if trigger_match:
                triggers = trigger_match.group(1).replace("'", "").split(", ")
                summary.append(f"\n### Trigger Differences ({len(triggers)})\n")
                summary.append("```\n")
                summary.append("\n".join(triggers[:10]))
                summary.append("\n```\n")
            break
    
    summary.append("\n📄 **Full details available in workflow logs above**\n")
    
    return "".join(summary)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: parse_drift.py <drift_output.txt>")
        sys.exit(1)
    
    output = parse_drift_output(sys.argv[1])
    print(output)

