#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Patent Diagram Generator for GROUP-6 v11
Generates FIG. 19 (DCREE Execution Pipeline) and FIG. 20 (NRO Integration)
Output: 1200x700px PNG at 300 DPI
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Polygon, Ellipse, Wedge
import matplotlib.lines as mlines
import numpy as np
from PIL import Image


class PatentDiagramGenerator:
    """Generator for patent-quality technical diagrams"""

    def __init__(self, width=12, height=7):
        """Initialize diagram with specified dimensions (in inches for DPI calculation)"""
        self.fig, self.ax = plt.subplots(figsize=(width, height))
        self.ax.set_xlim(0, 100)
        self.ax.set_ylim(0, 100)
        self.ax.axis('off')
        self.fig.patch.set_facecolor('white')

        # Color palette matching PPTX samples
        self.colors = {
            'process': '#4A90E2',      # Blue - Process nodes
            'decision': '#F5A623',     # Orange - Decision nodes
            'data': '#7ED321',         # Green - Data sources
            'warning': '#F8E71C',      # Yellow - Warnings
            'critical': '#D0021B',     # Red - Critical actions
            'specialized': '#BD10E0',  # Purple - ZK/AI systems
            'neutral': '#9B9B9B'       # Gray - Terminal nodes
        }

    def add_rounded_box(self, x, y, width, height, label, color, sublabel=None, symbol=''):
        """Add rounded rectangle node"""
        box = FancyBboxPatch(
            (x, y), width, height,
            boxstyle="round,pad=0.8",
            facecolor=color,
            edgecolor='black',
            linewidth=2.5,
            alpha=0.85
        )
        self.ax.add_patch(box)

        # Main label
        label_text = f"{label} {symbol}" if symbol else label
        self.ax.text(
            x + width/2, y + height/2 + 1,
            label_text,
            ha='center', va='center',
            fontsize=11, fontweight='bold',
            color='white', wrap=True
        )

        # Sublabel
        if sublabel:
            self.ax.text(
                x + width/2, y + height/2 - 2,
                sublabel,
                ha='center', va='center',
                fontsize=9, fontstyle='italic',
                color='white'
            )

    def add_hexagon(self, x, y, size, label, color, sublabel=None, symbol=''):
        """Add hexagon node for specialized systems"""
        angles = np.linspace(0, 2*np.pi, 7)
        hex_x = x + size * np.cos(angles)
        hex_y = y + size * np.sin(angles)

        hexagon = Polygon(
            list(zip(hex_x, hex_y)),
            facecolor=color,
            edgecolor='black',
            linewidth=2.5,
            alpha=0.85
        )
        self.ax.add_patch(hexagon)

        # Label
        label_text = f"{label} {symbol}" if symbol else label
        self.ax.text(
            x, y + 1,
            label_text,
            ha='center', va='center',
            fontsize=11, fontweight='bold',
            color='white', wrap=True
        )

        if sublabel:
            self.ax.text(
                x, y - 2,
                sublabel,
                ha='center', va='center',
                fontsize=9, fontstyle='italic',
                color='white'
            )

    def add_diamond(self, x, y, width, height, label, color):
        """Add diamond-shaped decision node"""
        diamond_points = [
            (x, y + height/2),      # Top
            (x + width/2, y),       # Right
            (x, y - height/2),      # Bottom
            (x - width/2, y)        # Left
        ]

        diamond = Polygon(
            diamond_points,
            facecolor=color,
            edgecolor='black',
            linewidth=2.5,
            alpha=0.85
        )
        self.ax.add_patch(diamond)

        self.ax.text(
            x, y,
            label,
            ha='center', va='center',
            fontsize=10, fontweight='bold',
            color='white', wrap=True
        )

    def add_cylinder(self, x, y, width, height, label, color, sublabel=None, symbol=''):
        """Add cylinder shape for human interface/database"""
        # Main rectangle
        rect = FancyBboxPatch(
            (x, y), width, height,
            boxstyle="round,pad=0.3",
            facecolor=color,
            edgecolor='black',
            linewidth=2.5,
            alpha=0.85
        )
        self.ax.add_patch(rect)

        # Top ellipse
        ellipse_top = Ellipse(
            (x + width/2, y + height),
            width, height*0.2,
            facecolor=color,
            edgecolor='black',
            linewidth=2.5,
            alpha=0.85
        )
        self.ax.add_patch(ellipse_top)

        # Label
        label_text = f"{label} {symbol}" if symbol else label
        self.ax.text(
            x + width/2, y + height/2,
            label_text,
            ha='center', va='center',
            fontsize=11, fontweight='bold',
            color='white'
        )

        if sublabel:
            self.ax.text(
                x + width/2, y + height/2 - 2,
                sublabel,
                ha='center', va='center',
                fontsize=9, fontstyle='italic',
                color='white'
            )

    def add_arrow(self, start_xy, end_xy, style='solid', label=None, color='#333333'):
        """Add connecting arrow between nodes"""
        linestyle_map = {
            'solid': '-',
            'dashed': '--',
            'dotted': ':'
        }

        arrow = FancyArrowPatch(
            start_xy, end_xy,
            arrowstyle='-|>',
            mutation_scale=25,
            linewidth=3,
            color=color,
            linestyle=linestyle_map.get(style, '-')
        )
        self.ax.add_patch(arrow)

        if label:
            mid_x = (start_xy[0] + end_xy[0]) / 2
            mid_y = (start_xy[1] + end_xy[1]) / 2
            self.ax.text(
                mid_x, mid_y + 1,
                label,
                ha='center', va='center',
                fontsize=9,
                bbox=dict(boxstyle='round,pad=0.4', facecolor='white',
                         edgecolor='gray', alpha=0.9)
            )

    def add_title(self, title, subtitle=None, fig_number=None):
        """Add diagram title and number"""
        # Figure number (top right)
        if fig_number:
            self.ax.text(
                95, 95,
                f"- {fig_number} -",
                ha='right', va='top',
                fontsize=14, fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.5', facecolor='white',
                         edgecolor='black', linewidth=2)
            )

        # Main title
        self.ax.text(
            50, 96,
            title,
            ha='center', va='top',
            fontsize=16, fontweight='bold'
        )

        # Subtitle
        if subtitle:
            self.ax.text(
                50, 92,
                subtitle,
                ha='center', va='top',
                fontsize=12
            )

    def add_legend(self, items):
        """Add custom legend"""
        legend_elements = []
        for marker, color, label in items:
            legend_elements.append(
                mlines.Line2D([0], [0], marker='s', color='w',
                            markerfacecolor=color,
                            markersize=10, label=label)
            )

        self.ax.legend(
            handles=legend_elements,
            loc='lower center',
            ncol=len(items)//2 + 1,
            frameon=True,
            fancybox=True,
            shadow=True,
            fontsize=9
        )

    def add_text_box(self, x, y, width, height, text, bgcolor='#F5F5F5'):
        """Add informational text box"""
        box = FancyBboxPatch(
            (x, y), width, height,
            boxstyle="round,pad=0.5",
            facecolor=bgcolor,
            edgecolor='black',
            linewidth=2,
            alpha=0.9
        )
        self.ax.add_patch(box)

        self.ax.text(
            x + width/2, y + height/2,
            text,
            ha='center', va='center',
            fontsize=9, wrap=True
        )

    def save(self, filename, dpi=300):
        """Save diagram as high-resolution PNG"""
        plt.tight_layout()
        plt.savefig(
            filename,
            dpi=dpi,
            bbox_inches='tight',
            facecolor='white',
            edgecolor='none',
            format='png'
        )
        print(f"✓ Saved: {filename}")
        plt.close()


def generate_fig19():
    """Generate FIG. 19: DCREE Execution Pipeline"""
    print("\n=== Generating FIG. 19: DCREE Execution Pipeline ===")

    diagram = PatentDiagramGenerator()

    # Title
    diagram.add_title(
        "【도 19】 DCREE Execution Pipeline",
        "Automated Valuation → Dynamic Risk Model (DRM) → ALC → LTP",
        fig_number="19"
    )

    # System header
    diagram.add_text_box(
        10, 82, 80, 5,
        "L8 DCREE (Decentralized Collateral Risk & Enforcement Engine)",
        bgcolor='#E8F4F8'
    )

    # Node 1: Automated Valuation Engine
    diagram.add_rounded_box(
        x=10, y=65, width=16, height=10,
        label="AUTOMATED\nVALUATION",
        color=diagram.colors['data'],
        sublabel="GROUP-2B",
        symbol="▲"
    )

    # Node 2: Dynamic Risk Modeling
    diagram.add_hexagon(
        x=42, y=70, size=8,
        label="DYNAMIC RISK\nMODEL",
        color=diagram.colors['specialized'],
        sublabel="DRM [1010]",
        symbol="⬠"
    )

    # Oracle connection (dashed)
    diagram.add_rounded_box(
        x=52, y=78, width=12, height=5,
        label="Oracle\nGROUP-4",
        color=diagram.colors['neutral'],
        symbol="○"
    )
    diagram.add_arrow((58, 78), (45, 75), style='dashed', label='data feed')

    # Arrow: Valuation → DRM
    diagram.add_arrow((26, 70), (34, 70), style='solid', label='RWA data')

    # Node 3: Decision Point
    diagram.add_diamond(
        x=42, y=52, width=16, height=12,
        label="QR-CR <\nThreshold?",
        color=diagram.colors['decision']
    )

    # Arrow: DRM → Decision
    diagram.add_arrow((42, 62), (42, 58), style='solid')

    # Node 4: Autonomous Liquidation Contract (ALC)
    diagram.add_rounded_box(
        x=34, y=32, width=16, height=10,
        label="AUTONOMOUS\nLIQUIDATION",
        color=diagram.colors['critical'],
        sublabel="ALC Contract",
        symbol="●"
    )

    # Arrow: Decision → ALC (YES path)
    diagram.add_arrow((42, 46), (42, 42), style='solid', label='YES')

    # Arrow: Decision → Monitor (NO path - loop back)
    diagram.add_arrow((50, 52), (60, 52), style='dashed', label='NO')
    diagram.add_arrow((60, 52), (60, 70), style='dashed')
    diagram.add_arrow((60, 70), (50, 70), style='dashed', label='Continue\nMonitoring')

    # Node 5: Legal Twinning Protocol
    diagram.add_rounded_box(
        x=34, y=15, width=16, height=10,
        label="LEGAL\nTWINNING",
        color=diagram.colors['process'],
        sublabel="LTP [1020]",
        symbol="◆"
    )

    # Arrow: ALC → LTP
    diagram.add_arrow((42, 32), (42, 25), style='solid', label='Issue AFC')

    # Final output indicator
    diagram.add_text_box(
        34, 5, 16, 5,
        "Legal Registry\nUpdate Complete",
        bgcolor='#E8F8E8'
    )
    diagram.add_arrow((42, 15), (42, 10), style='solid')

    # Legend
    diagram.add_legend([
        ('s', diagram.colors['data'], '▲ Data Source'),
        ('s', diagram.colors['process'], '◆ Process Node'),
        ('s', diagram.colors['specialized'], '⬠ AI/ML System'),
        ('s', diagram.colors['critical'], '● Critical Action'),
        ('s', diagram.colors['decision'], 'Decision Point')
    ])

    # Additional info boxes (right side)
    diagram.add_text_box(
        65, 65, 20, 8,
        "Key Concepts:\n\n• QR-CR: Quantum-\n  Resistant Coverage\n  Ratio\n• AFC: Atomic\n  Foreclosure\n  Command",
        bgcolor='#FFFEF0'
    )

    diagram.save('/mnt/user-data/outputs/GROUP-6-v11-FIG-019.png')


def generate_fig20():
    """Generate FIG. 20: NRO Integration - Neuralink Signals → DRM"""
    print("\n=== Generating FIG. 20: NRO Integration ===")

    diagram = PatentDiagramGenerator()

    # Title
    diagram.add_title(
        "【도 20】 NRO Integration",
        "Neuralink Signals → DRM Threshold Adjustment (L9 Layer)",
        fig_number="20"
    )

    # System header
    diagram.add_text_box(
        5, 82, 90, 5,
        "L9 NRO (Neuralink-Enhanced Risk Oracle) - Human-AI Hybrid Verification",
        bgcolor='#F8E8F8'
    )

    # Layer indicator
    diagram.ax.text(
        5, 88, "L9 Layer",
        ha='left', va='center',
        fontsize=12, fontweight='bold',
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#BD10E0',
                 edgecolor='black', alpha=0.7)
    )

    # Node 1: BCI-Equipped Operator
    diagram.add_cylinder(
        x=10, y=65, width=14, height=10,
        label="BCI OPERATOR",
        color=diagram.colors['critical'],
        sublabel="Neuralink\nInterface",
        symbol="●"
    )

    # Human icon indicator
    diagram.ax.text(
        17, 77, "👤",
        ha='center', va='center',
        fontsize=20
    )

    # Node 2: DRM Threshold Breach Detection
    diagram.add_hexagon(
        x=40, y=70, size=8,
        label="DRM ALERT",
        color=diagram.colors['warning'],
        sublabel="QR-CR Warning",
        symbol="⚠"
    )

    # Arrow: Operator monitors DRM
    diagram.add_arrow((24, 70), (32, 70), style='dashed', label='monitors')

    # Trigger event
    diagram.add_text_box(
        32, 78, 16, 4,
        "Bio-Confirmed\nAlert (BCA)",
        bgcolor='#FFF0F0'
    )
    diagram.add_arrow((40, 78), (40, 75), style='solid')

    # Node 3: Neuralink Signal Capture
    diagram.add_rounded_box(
        x=32, y=52, width=16, height=10,
        label="NEURALINK\nSIGNAL",
        color=diagram.colors['specialized'],
        sublabel="NS Capture [1050]",
        symbol="⬠"
    )

    # Arrow: Alert → NS Capture
    diagram.add_arrow((40, 62), (40, 62), style='solid', label='Trigger BCI')

    # Timing indicator
    diagram.add_text_box(
        50, 57, 12, 4,
        "ms-level\nresponse",
        bgcolor='#F0F0FF'
    )

    # Node 4: Bio-Verified Execution Proof (BVEP)
    diagram.add_hexagon(
        x=40, y=38, size=8,
        label="BIO-VERIFIED\nPROOF",
        color=diagram.colors['data'],
        sublabel="BVEP [1060]",
        symbol="⬠"
    )

    # Arrow: NS → BVEP
    diagram.add_arrow((40, 52), (40, 46), style='solid', label='Generate\nproof')

    # ZK Infrastructure connection
    diagram.add_rounded_box(
        x=55, y=35, width=12, height=6,
        label="ZK Circuit\nGROUP-3",
        color=diagram.colors['specialized'],
        symbol="⬠"
    )
    diagram.add_arrow((48, 38), (55, 38), style='dashed', label='ZK signing')

    # Node 5: Decision Point - BVEP Valid?
    diagram.add_diamond(
        x=40, y=20, width=16, height=12,
        label="BVEP\nValid?",
        color=diagram.colors['decision']
    )

    # Arrow: BVEP → Decision
    diagram.add_arrow((40, 30), (40, 26), style='solid')

    # Node 6: ALC Authorization
    diagram.add_rounded_box(
        x=25, y=2, width=16, height=8,
        label="ALC\nAUTHORIZATION",
        color=diagram.colors['process'],
        sublabel="Issue AFC",
        symbol="◆"
    )

    # Arrow: Decision → ALC (YES path)
    diagram.add_arrow((35, 15), (33, 10), style='solid', label='YES')

    # Node 7: Abort path
    diagram.add_rounded_box(
        x=55, y=15, width=12, height=6,
        label="ABORT AFC",
        color=diagram.colors['neutral'],
        symbol="✖"
    )

    # Arrow: Decision → Abort (NO path)
    diagram.add_arrow((48, 20), (56, 18), style='dashed', label='NO')

    # Proceed to LTP indicator
    diagram.add_text_box(
        15, -6, 16, 4,
        "→ Proceed to\nLTP Execution",
        bgcolor='#E8F8E8'
    )
    diagram.add_arrow((33, 2), (28, -4), style='solid')

    # Legend
    diagram.add_legend([
        ('s', diagram.colors['critical'], '● Human Interface'),
        ('s', diagram.colors['specialized'], '⬠ BCI/ZK System'),
        ('s', diagram.colors['warning'], '⚠ Alert/Warning'),
        ('s', diagram.colors['data'], 'Verification Proof'),
        ('s', diagram.colors['decision'], 'Decision Point')
    ])

    # Safety assurance box (bottom right)
    diagram.add_text_box(
        65, 5, 25, 15,
        "🛡️ Cosmic-Grade\nReliability (CGR)\n\n" +
        "Zero false-positive\nliquidations via\nhuman-verified BCI\nconfirmation\n\n" +
        "Human intent\nvalidation prevents\nautonomous errors",
        bgcolor='#E8FFE8'
    )

    diagram.save('/mnt/user-data/outputs/GROUP-6-v11-FIG-020.png')


def validate_diagram(filepath):
    """Validate generated diagram meets specifications"""
    try:
        img = Image.open(filepath)

        # Check dimensions
        width, height = img.size
        print(f"\n  Size: {width}×{height}px", end='')

        # Check DPI
        dpi = img.info.get('dpi', (0, 0))
        print(f", DPI: {dpi[0]:.0f}")

        # Validate specifications
        checks = []
        checks.append(("Width >= 1000px", width >= 1000))
        checks.append(("Height >= 600px", height >= 600))
        checks.append(("DPI >= 300", dpi[0] >= 300))

        all_passed = all(result for _, result in checks)

        for check_name, result in checks:
            status = "✓" if result else "✗"
            print(f"  {status} {check_name}")

        if all_passed:
            print(f"  ✓ {filepath} validated successfully")
        else:
            print(f"  ⚠ Some checks failed for {filepath}")

        return all_passed

    except Exception as e:
        print(f"  ✗ Error validating {filepath}: {e}")
        return False


def main():
    """Main execution function"""
    print("\n" + "="*70)
    print("PATENT DIAGRAM GENERATOR - GROUP-6 v11")
    print("="*70)

    # Generate both diagrams
    generate_fig19()
    generate_fig20()

    # Validate outputs
    print("\n" + "="*70)
    print("VALIDATION RESULTS")
    print("="*70)

    fig19_valid = validate_diagram('/mnt/user-data/outputs/GROUP-6-v11-FIG-019.png')
    fig20_valid = validate_diagram('/mnt/user-data/outputs/GROUP-6-v11-FIG-020.png')

    # Summary
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)

    if fig19_valid and fig20_valid:
        print("✓ Both diagrams generated successfully")
        print("✓ All quality checks passed")
        print("\nOutput files:")
        print("  • /mnt/user-data/outputs/GROUP-6-v11-FIG-019.png")
        print("  • /mnt/user-data/outputs/GROUP-6-v11-FIG-020.png")
    else:
        print("⚠ Some validation checks failed")
        print("Review the validation results above")

    print("="*70 + "\n")


if __name__ == "__main__":
    main()
