"""Generate extra Cubism motion3/exp3 files for the dafeiyu model.

The model only shipped with Idle / speak / thinkend / thinking and five
expressions. These are hand-authored parameter curves used by the private-chat
stage for pat / poke / double-tap reactions. Run from the app root:

    python tool/gen_live2d_anim.py
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets" / "live2d" / "dafeiyu"


def motion(name: str, curves: dict[str, list[tuple[float, float]]]) -> None:
    out_curves = []
    total_segments = 0
    total_points = 0
    duration = 0.0
    for param_id, points in curves.items():
        assert len(points) >= 2, param_id
        points = sorted(points)
        segments: list[float] = [points[0][0], points[0][1]]
        for (t0, v0), (t1, v1) in zip(points, points[1:]):
            if t1 <= t0:
                continue
            # 线性段（segment id 0）：Cubism 对 motion3 的 Bézier 段校验较严，
            # 手写文件用线性段最稳；短反应动作靠多打几个关键点就够顺。
            segments.extend([0, t1, v1])
            total_segments += 1
        total_points += len(points)
        duration = max(duration, points[-1][0])
        out_curves.append(
            {"Target": "Parameter", "Id": param_id, "Segments": segments}
        )
    data = {
        "Version": 3,
        "Meta": {
            "Duration": round(duration, 3),
            "Fps": 60.0,
            "Loop": False,
            "AreBeziersRestricted": False,
            "CurveCount": len(out_curves),
            "TotalSegmentCount": total_segments,
            "TotalPointCount": total_points,
            "UserDataCount": 0,
            "TotalUserDataSize": 0,
        },
        "Curves": out_curves,
        "UserData": [],
    }
    (MODEL / f"{name}.motion3.json").write_text(
        json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )


def expression(name: str, params: list[tuple[str, float, str]]) -> None:
    data = {
        "Type": "Live2D Expression",
        "Parameters": [
            {"Id": pid, "Value": value, "Blend": blend}
            for pid, value, blend in params
        ],
    }
    (MODEL / f"{name}.exp3.json").write_text(
        json.dumps(data, ensure_ascii=False, indent="\t"),
        encoding="utf-8",
    )


def main() -> None:
    # Pat / head touch: nod + shy.
    motion(
        "nod",
        {
            "ParamAngleY": [(0.0, 0.0), (0.28, -10.0), (0.58, 0.0), (0.9, -5.0), (1.3, 0.0)],
            "ParamAngleZ": [(0.0, 0.0), (0.4, 3.0), (1.3, 0.0)],
            "ParamBodyAngleX": [(0.0, 0.0), (0.45, 2.0), (1.3, 0.0)],
            "ParamEyeLOpen": [(0.0, 1.0), (0.35, 0.88), (1.0, 1.0)],
            "ParamEyeROpen": [(0.0, 1.0), (0.35, 0.88), (1.0, 1.0)],
            "ParamMouthForm": [(0.0, 0.0), (0.4, 0.6), (1.3, 0.0)],
            "ParamMouthOpenY": [(0.0, 0.0), (0.4, 0.15), (1.3, 0.0)],
            "ParamHairFront": [(0.0, 0.0), (0.4, 2.0), (1.3, 0.0)],
            "Param2": [(0.0, 0.0), (0.4, 1.0), (1.3, 0.0)],
        },
    )

    # Poke / surprise.
    motion(
        "surprise",
        {
            "ParamAngleY": [(0.0, 0.0), (0.22, 12.0), (1.1, 0.0)],
            "ParamAngleZ": [(0.0, 0.0), (0.25, -6.0), (1.1, 0.0)],
            "ParamEyeLOpen": [(0.0, 1.0), (0.2, 1.25), (0.8, 1.0)],
            "ParamEyeROpen": [(0.0, 1.0), (0.2, 1.25), (0.8, 1.0)],
            "ParamMouthOpenY": [(0.0, 0.0), (0.2, 1.0), (0.7, 0.0)],
            "ParamBrowLY": [(0.0, 0.0), (0.2, 1.0), (0.9, 0.0)],
            "ParamBrowRY": [(0.0, 0.0), (0.2, 1.0), (0.9, 0.0)],
            "ParamBodyAngleX": [(0.0, 0.0), (0.25, -3.0), (1.1, 0.0)],
            "ParamHairFront": [(0.0, 0.0), (0.25, -4.0), (1.1, 0.0)],
            "Param2": [(0.0, 0.0), (0.25, -1.0), (1.1, 0.0)],
        },
    )

    # Shy / embarrassed.
    motion(
        "shy",
        {
            "ParamAngleY": [(0.0, 0.0), (0.5, -8.0), (1.1, -4.0), (1.9, 0.0)],
            "ParamAngleZ": [(0.0, 0.0), (0.5, 6.0), (1.2, 3.0), (1.9, 0.0)],
            "ParamEyeLSmile": [(0.0, 0.0), (0.5, 1.0), (1.6, 0.0)],
            "ParamEyeRSmile": [(0.0, 0.0), (0.5, 1.0), (1.6, 0.0)],
            "ParamEyeLOpen": [(0.0, 1.0), (0.5, 0.7), (1.9, 1.0)],
            "ParamEyeROpen": [(0.0, 1.0), (0.5, 0.7), (1.9, 1.0)],
            "ParamMouthForm": [(0.0, 0.0), (0.5, 0.5), (1.2, 0.2), (1.9, 0.0)],
            "ParamMouthOpenY": [(0.0, 0.0), (0.6, 0.2), (1.9, 0.0)],
            "ParamBodyAngleX": [(0.0, 0.0), (0.5, 3.0), (1.9, 0.0)],
            "ParamHairBack": [(0.0, 0.0), (0.7, 3.0), (1.9, 0.0)],
            "Param": [(0.0, 0.0), (0.6, 1.0), (1.4, 0.0)],
        },
    )

    # Double tap / bounce.
    motion(
        "bounce",
        {
            "ParamAngleY": [(0.0, 0.0), (0.2, 10.0), (0.55, -4.0), (1.3, 0.0)],
            "ParamBodyAngleY": [(0.0, 0.0), (0.2, 4.0), (0.55, -2.0), (1.3, 0.0)],
            "ParamAngleZ": [(0.0, 0.0), (0.2, -4.0), (0.6, 2.0), (1.3, 0.0)],
            "ParamHairFront": [(0.0, 0.0), (0.25, -4.0), (0.65, 2.0), (1.3, 0.0)],
            "ParamHairBack": [(0.0, 0.0), (0.3, -4.0), (0.7, 2.0), (1.3, 0.0)],
            "ParamSkirtFlap": [(0.0, 0.0), (0.25, 2.0), (0.7, -1.0), (1.3, 0.0)],
            "ParamTwinTails": [(0.0, 0.0), (0.3, 3.0), (0.7, -2.0), (1.3, 0.0)],
            "Param2": [(0.0, 0.0), (0.2, -2.0), (0.65, 1.0), (1.3, 0.0)],
            "ParamMouthOpenY": [(0.0, 0.0), (0.2, 0.4), (1.3, 0.0)],
        },
    )

    # Tail wag / happy idle.
    motion(
        "tailwag",
        {
            "Param": [(0.0, 0.0), (0.4, 1.0), (0.9, -1.0), (1.4, 1.0), (2.0, 0.0)],
            "ParamHairBack": [(0.0, 0.0), (0.4, 2.0), (0.9, -2.0), (1.4, 2.0), (2.0, 0.0)],
            "ParamTwinTails": [(0.0, 0.0), (0.4, 2.0), (0.9, -2.0), (1.4, 2.0), (2.0, 0.0)],
            "ParamAngleZ": [(0.0, 0.0), (0.5, 2.0), (1.0, -2.0), (1.5, 1.0), (2.0, 0.0)],
            "ParamBodyAngleX": [(0.0, 0.0), (0.5, 2.0), (1.0, -2.0), (1.5, 1.0), (2.0, 0.0)],
            "ParamEyeLSmile": [(0.0, 0.0), (0.6, 0.8), (1.6, 0.0)],
            "ParamEyeRSmile": [(0.0, 0.0), (0.6, 0.8), (1.6, 0.0)],
        },
    )

    # Concert / happy wave.
    motion(
        "wave",
        {
            "ParamAngleZ": [(0.0, 0.0), (0.45, -8.0), (1.0, 8.0), (1.55, -8.0), (2.2, 0.0)],
            "ParamBodyAngleX": [(0.0, 0.0), (0.45, 4.0), (1.0, -4.0), (1.55, 4.0), (2.2, 0.0)],
            "ParamAngleY": [(0.0, 0.0), (0.5, 4.0), (1.6, 0.0)],
            "ParamHairFront": [(0.0, 0.0), (0.5, 4.0), (1.0, -4.0), (1.6, 4.0), (2.2, 0.0)],
            "ParamTwinTails": [(0.0, 0.0), (0.5, 3.0), (1.0, -3.0), (1.6, 3.0), (2.2, 0.0)],
            "ParamMouthForm": [(0.0, 0.0), (0.5, 0.6), (1.6, 0.0)],
            "ParamEyeLSmile": [(0.0, 0.0), (0.5, 1.0), (1.6, 0.0)],
            "ParamEyeRSmile": [(0.0, 0.0), (0.5, 1.0), (1.6, 0.0)],
            "ParamMouthOpenY": [(0.0, 0.0), (0.6, 0.3), (1.6, 0.0)],
        },
    )

    # Extra expressions.
    expression(
        "shy",
        [
            ("ParamEyeLSmile", 1, "Add"),
            ("ParamEyeRSmile", 1, "Add"),
            ("ParamEyeLOpen", -0.2, "Add"),
            ("ParamEyeROpen", -0.2, "Add"),
            ("ParamMouthForm", 0.7, "Add"),
            ("ParamMouthOpenY", 0.2, "Add"),
            ("ParamBrowLY", -0.4, "Add"),
            ("ParamBrowRY", -0.4, "Add"),
            ("ParamAngleZ", 5, "Add"),
            ("ParamBodyAngleX", 3, "Add"),
            ("Param", 1, "Add"),
        ],
    )
    expression(
        "pout",
        [
            ("ParamMouthForm", -1, "Add"),
            ("ParamBrowLY", -1, "Add"),
            ("ParamBrowRY", -1, "Add"),
            ("ParamBrowLAngle", -1, "Add"),
            ("ParamBrowRAngle", 1, "Add"),
            ("ParamEyeLOpen", -0.3, "Add"),
            ("ParamEyeROpen", -0.3, "Add"),
            ("ParamAngleZ", -4, "Add"),
            ("ParamBodyAngleX", -2, "Add"),
        ],
    )
    expression(
        "surprised",
        [
            ("ParamEyeLOpen", 0.2, "Add"),
            ("ParamEyeROpen", 0.2, "Add"),
            ("ParamMouthOpenY", 1, "Add"),
            ("ParamBrowLY", 1, "Add"),
            ("ParamBrowRY", 1, "Add"),
            ("ParamAngleY", 8, "Add"),
            ("ParamBodyAngleY", -3, "Add"),
            ("ParamHairFront", -3, "Add"),
            ("Param2", -1, "Add"),
        ],
    )
    expression(
        "sleepy",
        [
            ("ParamEyeLOpen", -0.8, "Add"),
            ("ParamEyeROpen", -0.8, "Add"),
            ("ParamBrowLY", -0.5, "Add"),
            ("ParamBrowRY", -0.5, "Add"),
            ("ParamMouthForm", 0.2, "Add"),
            ("ParamAngleZ", 4, "Add"),
            ("ParamBodyAngleZ", 2, "Add"),
            ("Param2", -1, "Add"),
            ("ParamHairFront", 1, "Add"),
        ],
    )
    expression(
        "smug",
        [
            ("ParamEyeLSmile", 1, "Add"),
            ("ParamEyeRSmile", 1, "Add"),
            ("ParamEyeLOpen", 0, "Add"),
            ("ParamEyeROpen", 0, "Add"),
            ("ParamMouthForm", 0.8, "Add"),
            ("ParamBrowLY", 0.5, "Add"),
            ("ParamBrowRY", -0.3, "Add"),
            ("ParamAngleZ", -4, "Add"),
            ("ParamAngleY", 3, "Add"),
            ("Param2", 1, "Add"),
        ],
    )
    expression(
        "wink",
        [
            ("ParamEyeLOpen", -1, "Add"),
            ("ParamEyeLSmile", 0, "Add"),
            ("ParamEyeROpen", 0, "Add"),
            ("ParamEyeRSmile", 1, "Add"),
            ("ParamMouthForm", 0.8, "Add"),
            ("ParamMouthOpenY", 0.1, "Add"),
            ("ParamAngleZ", 3, "Add"),
        ],
    )
    expression(
        "sad",
        [
            ("ParamEyeLOpen", -0.4, "Add"),
            ("ParamEyeROpen", -0.4, "Add"),
            ("ParamBrowLY", -1, "Add"),
            ("ParamBrowRY", -1, "Add"),
            ("ParamBrowLAngle", -1, "Add"),
            ("ParamBrowRAngle", 1, "Add"),
            ("ParamMouthForm", -1, "Add"),
            ("ParamAngleY", -6, "Add"),
            ("ParamBodyAngleY", 2, "Add"),
        ],
    )
    expression(
        "love",
        [
            ("ParamEyeLSmile", 1, "Add"),
            ("ParamEyeRSmile", 1, "Add"),
            ("ParamEyeLOpen", 0, "Add"),
            ("ParamEyeROpen", 0, "Add"),
            ("ParamMouthForm", 1, "Add"),
            ("ParamMouthOpenY", 0.3, "Add"),
            ("ParamAngleZ", 6, "Add"),
            ("Param", 1, "Add"),
            ("ParamTwinTails", 2, "Add"),
        ],
    )
    expression(
        "angry",
        [
            ("ParamBrowLAngle", 1, "Add"),
            ("ParamBrowRAngle", -1, "Add"),
            ("ParamBrowLY", -0.8, "Add"),
            ("ParamBrowRY", -0.8, "Add"),
            ("ParamMouthForm", -1, "Add"),
            ("ParamEyeLOpen", 0.2, "Add"),
            ("ParamEyeROpen", 0.2, "Add"),
            ("ParamAngleZ", -3, "Add"),
            ("ParamBodyAngleX", -2, "Add"),
        ],
    )

    print("wrote", len(list(MODEL.glob("*.motion3.json"))), "motions,",
          len(list(MODEL.glob("*.exp3.json"))), "expressions")


if __name__ == "__main__":
    main()
