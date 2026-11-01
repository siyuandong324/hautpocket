#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
河南工业大学正方教务管理系统（V9/N9）综合信息爬虫
目标网址: https://jwglxt.haut.edu.cn/jwglxt/xtgl/login_slogin.html
支持抓取模块:
  1. 信息查询 -> 个人课表查询（课程名称、上课时间、上课地点、任课教师、实践课等）
  2. 信息查询 -> 查询个人信息（学籍基本信息、成绩信息、选课信息）
  3. 自动导出包含【个人课表查询信息、查询个人信息（学籍基本信息、成绩信息、选课信息）】的完整 UTF-8 JSON 文件

依赖安装:
  pip install requests beautifulsoup4 rsa
  （或使用 cryptography 库代替 rsa：pip install requests beautifulsoup4 cryptography）
"""

import argparse
import base64
import json
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import requests
from bs4 import BeautifulSoup


def rsa_encrypt_password(password: str, modulus_b64: str, exponent_b64: str) -> str:
    """
    使用正方教务系统下发的 Base64 格式 modulus 和 exponent 对密码进行 RSA PKCS#1 v1.5 加密。
    优先使用 `rsa` 库，若未安装则自动回退至 `cryptography` 库。
    """
    modulus_bytes = base64.b64decode(modulus_b64)
    exponent_bytes = base64.b64decode(exponent_b64)
    n = int.from_bytes(modulus_bytes, byteorder="big")
    e = int.from_bytes(exponent_bytes, byteorder="big")
    password_bytes = password.encode("utf-8")

    # 方案 1：使用 rsa 库
    try:
        import rsa  # type: ignore

        pub_key = rsa.PublicKey(n, e)
        crypto_bytes = rsa.encrypt(password_bytes, pub_key)
        return base64.b64encode(crypto_bytes).decode("utf-8")
    except ImportError:
        pass

    # 方案 2：回退使用 cryptography 库
    try:
        from cryptography.hazmat.primitives.asymmetric import padding, rsa as crypto_rsa

        public_numbers = crypto_rsa.RSAPublicNumbers(e, n)
        public_key = public_numbers.public_key()
        crypto_bytes = public_key.encrypt(password_bytes, padding.PKCS1v15())
        return base64.b64encode(crypto_bytes).decode("utf-8")
    except ImportError as exc:
        raise RuntimeError(
            "缺少 RSA 加密依赖库，请运行 `pip install rsa` 或 `pip install cryptography`。"
        ) from exc


class HAUTJwglxtSpider:
    """河南工业大学正方教务管理系统（N9/V9.0）综合查询爬虫客户端"""

    # 正方系统学期编码映射：1 -> 3 (第一学期/秋), 2 -> 12 (第二学期/春), 3 -> 16 (第三学期/夏)
    TERM_CODE_MAP = {
        "1": "3",
        "2": "12",
        "3": "16",
        "12": "12",
        "16": "16",
        "all": "",
        "": "",
    }

    def __init__(
        self,
        username: str,
        password: str,
        base_url: str = "https://jwglxt.haut.edu.cn/jwglxt",
        timeout: int = 15,
    ) -> None:
        self.username = username
        self.password = password
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

        self.session = requests.Session()
        # 注意：不要在 Accept-Encoding 中声明 br，避免未安装 brotli 时无法解压
        self.session.headers.update(
            {
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/128.0.0.0 Safari/537.36"
                ),
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                "Connection": "keep-alive",
            }
        )

    def _resolve_term_code(self, term: Optional[str]) -> str:
        """将常见学期输入（1/2/3 或 3/12/16 或 all）转换为正方内部学期码 xqm"""
        if term is None:
            return ""
        term_str = str(term).strip().lower()
        return self.TERM_CODE_MAP.get(term_str, term_str)

    def set_cookie_string(self, cookie_str: str) -> None:
        """手动注入浏览器 Cookie（当遇到异地滑动验证码或使用统一身份认证时可直接使用）"""
        for item in cookie_str.split(";"):
            item = item.strip()
            if "=" in item:
                k, v = item.split("=", 1)
                self.session.cookies.set(k.strip(), v.strip())

    def login(self) -> bool:
        """执行正方教务系统模拟登录"""
        login_url = f"{self.base_url}/xtgl/login_slogin.html"
        pubkey_url = f"{self.base_url}/xtgl/login_getPublicKey.html"
        now_ms = int(time.time() * 1000)

        # 1. 访问登录页，初始化 Session Cookie 并提取 csrftoken
        resp_page = self.session.get(
            login_url,
            params={"language": "zh_CN", "_t": str(now_ms)},
            timeout=self.timeout,
        )
        resp_page.raise_for_status()

        soup = BeautifulSoup(resp_page.text, "html.parser")
        csrf_input = soup.find("input", {"id": "csrftoken"})
        if not csrf_input or not csrf_input.get("value"):
            raise RuntimeError("未能从登录页面解析到 csrftoken，请检查网络或教务系统地址是否可访问。")
        csrftoken = csrf_input["value"]

        # 2. 请求 RSA 公钥参数 (modulus, exponent)
        resp_key = self.session.get(
            pubkey_url,
            params={"time": str(int(time.time() * 1000)), "_": str(now_ms)},
            headers={"X-Requested-With": "XMLHttpRequest"},
            timeout=self.timeout,
        )
        resp_key.raise_for_status()
        pubkey_data = resp_key.json()
        modulus = pubkey_data.get("modulus")
        exponent = pubkey_data.get("exponent")
        if not modulus or not exponent:
            raise RuntimeError(f"获取 RSA 公钥失败，返回内容: {pubkey_data}")

        # 3. 加密明文密码
        encrypted_pwd = rsa_encrypt_password(self.password, modulus, exponent)

        # 4. 提交登录表单（正方 V9 表单包含两个同名 mm 字段：明文框与隐藏框）
        form_data = [
            ("csrftoken", csrftoken),
            ("language", "zh_CN"),
            ("yhm", self.username),
            ("mm", encrypted_pwd),
            ("mm", encrypted_pwd),
        ]
        post_headers = {
            "Origin": "https://jwglxt.haut.edu.cn",
            "Referer": login_url,
            "Content-Type": "application/x-www-form-urlencoded",
        }
        resp_login = self.session.post(
            f"{login_url}?time={int(time.time() * 1000)}",
            data=form_data,
            headers=post_headers,
            timeout=self.timeout,
            allow_redirects=True,
        )
        resp_login.raise_for_status()

        # 5. 判断是否登录成功
        if "login_slogin.html" in resp_login.url or 'id="tips"' in resp_login.text:
            err_soup = BeautifulSoup(resp_login.text, "html.parser")
            tips = err_soup.find(id="tips")
            err_msg = tips.get_text(strip=True) if tips else "未知登录错误（可能触发了验证码或密码有误）"
            raise RuntimeError(f"登录失败: {err_msg}")

        return True

    # =========================================================================
    # 模块 1：信息查询 -> 个人课表查询 (gnmkdm=N2151)
    # =========================================================================
    def fetch_raw_schedule(
        self, academic_year: str = "2026", term: str = "1", gnmkdm: str = "N2151"
    ) -> Dict[str, Any]:
        """
        向正方教务系统请求【个人课表查询】原始 JSON 数据。
        :param academic_year: 学年起始年份，如 "2025" 代表 2025-2026 学年，"2026" 代表 2026-2027 学年
        :param term: 学期，"1" 代表第一学期(3)，"2" 代表第二学期(12)，"3" 代表第三学期(16)
        """
        xqm = self._resolve_term_code(term) or "3"

        index_url = f"{self.base_url}/kbcx/xskbcx_cxXskbcxIndex.html"
        self.session.get(
            index_url,
            params={"gnmkdm": gnmkdm, "layout": "default"},
            timeout=self.timeout,
        )

        candidate_endpoints = [
            f"{self.base_url}/kbcx/xskbcx_cxXsgrkb.html?gnmkdm={gnmkdm}",
            f"{self.base_url}/kbcx/xskbcx_cxXsKb.html?gnmkdm={gnmkdm}",
        ]

        headers = {
            "X-Requested-With": "XMLHttpRequest",
            "Referer": f"{index_url}?gnmkdm={gnmkdm}&layout=default",
            "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
            "Accept": "application/json, text/javascript, */*; q=0.01",
        }
        payload = {
            "xnm": str(academic_year),
            "xqm": xqm,
            "kzlx": "ck",
            "xsdm": "",
        }

        last_error: Optional[Exception] = None
        for endpoint in candidate_endpoints:
            try:
                resp = self.session.post(
                    endpoint,
                    data=payload,
                    headers=headers,
                    timeout=self.timeout,
                )
                resp.raise_for_status()
                data = resp.json()
                if isinstance(data, dict) and ("kbList" in data or "xsxx" in data):
                    return data
            except Exception as exc:
                last_error = exc

        raise RuntimeError(
            f"获取个人课表 JSON 失败，请确认登录状态或学年({academic_year})/学期({term})设置。详情: {last_error}"
        )

    @staticmethod
    def parse_schedule_items(raw_data: Dict[str, Any]) -> Dict[str, Any]:
        """解析【个人课表查询】返回的数据，包括常规排课 (kbList) 与实践/其他课程 (sjkList)"""
        kb_list = raw_data.get("kbList") or []
        sjk_list = raw_data.get("sjkList") or []
        parsed_courses: List[Dict[str, Any]] = []

        for item in kb_list:
            course_name = (item.get("kcmc") or "").strip()
            teacher = (item.get("xm") or "未公布").strip()
            teacher_title = (item.get("zcmc") or "").strip()

            weekday = (item.get("xqjmc") or "").strip()  # 例如：星期一
            sessions = (item.get("jc") or item.get("jcor") or "").strip()  # 例如：1-2节
            weeks = (item.get("zcd") or "").strip()  # 例如：1-16周

            time_parts = [p for p in (weekday, sessions) if p]
            time_str = " ".join(time_parts)
            if weeks:
                time_str = f"{time_str} ({weeks})".strip()

            campus = (item.get("xqmc") or "").strip()
            classroom = (item.get("cdmc") or "未安排教室").strip()
            location = f"{campus} {classroom}".strip() if campus else classroom

            parsed_courses.append(
                {
                    "课程名称": course_name,
                    "时间": time_str,
                    "地点": location,
                    "老师": teacher,
                    "详细信息": {
                        "课程号": item.get("kch_id") or item.get("kch") or "",
                        "教学班": item.get("jxbmc") or "",
                        "星期": weekday,
                        "星期数字": item.get("xqj") or "",
                        "节次": sessions,
                        "周次": weeks,
                        "校区": campus,
                        "教室": classroom,
                        "教师职称": teacher_title,
                        "学分": item.get("xf") or "",
                        "考核方式": item.get("khfsmc") or "",
                        "课程学时组成": item.get("kcxszc") or "",
                        "周学时": item.get("zhxs") or "",
                        "总学时": item.get("zxs") or "",
                    },
                }
            )

        practical_courses: List[Dict[str, Any]] = []
        for sjk in sjk_list:
            practical_courses.append(
                {
                    "课程名称": (sjk.get("kcmc") or sjk.get("sjkcgs") or "").strip(),
                    "老师": (sjk.get("jsxm") or sjk.get("xm") or "").strip(),
                    "周次": (sjk.get("zcd") or sjk.get("qsjsz") or "").strip(),
                    "学分": sjk.get("xf") or "",
                    "实践课描述": (sjk.get("qtkcgs") or sjk.get("sjkcgs") or "").strip(),
                }
            )

        return {
            "课程总数": len(parsed_courses),
            "课表列表": parsed_courses,
            "实践及其他课程数": len(practical_courses),
            "实践及其他课程列表": practical_courses,
        }

    # =========================================================================
    # 模块 2：信息查询 -> 查询个人信息 (gnmkdm=N100801)
    # 含：学籍基本信息、个人信息中的成绩信息、个人信息中的选课信息
    # =========================================================================
    def fetch_personal_profile(self, gnmkdm: str = "N100801") -> Dict[str, Any]:
        """
        抓取【信息查询 -> 查询个人信息】中的学生基本信息与学籍信息。
        同时兼容 JSON 接口 (xsxxwh_cxCkDgxsxx.html) 与 HTML 页面解析 (xsgrxxwh_cxXsgrxx.html)。
        """
        profile: Dict[str, Any] = {}

        # 1. 先访问“查询个人信息”主页初始化上下文并解析 HTML 表单静态字段
        html_url = f"{self.base_url}/xsxxxggl/xsgrxxwh_cxXsgrxx.html"
        try:
            resp_html = self.session.get(
                html_url,
                params={"gnmkdm": gnmkdm, "layout": "default"},
                timeout=self.timeout,
            )
            if resp_html.status_code == 200 and "login_slogin" not in resp_html.url:
                soup = BeautifulSoup(resp_html.text, "html.parser")
                raw_fields: Dict[str, str] = {}
                for group in soup.select("div.form-group"):
                    label_el = group.select_one("label.control-label")
                    val_el = group.select_one("p.form-control-static, label.control-label + div")
                    if label_el and val_el:
                        key = label_el.get_text(strip=True).rstrip("：:").strip()
                        val = val_el.get_text(strip=True)
                        if key:
                            raw_fields[key] = val
                if raw_fields:
                    profile["页面解析字段"] = raw_fields
        except Exception:
            pass

        # 2. 请求单人学籍信息 JSON 接口
        json_url = f"{self.base_url}/xsxxxggl/xsxxwh_cxCkDgxsxx.html"
        try:
            resp_json = self.session.get(
                json_url,
                params={"gnmkdm": gnmkdm},
                headers={"X-Requested-With": "XMLHttpRequest"},
                timeout=self.timeout,
            )
            if resp_json.status_code == 200:
                info = resp_json.json()
                if isinstance(info, dict) and info:
                    profile.update(
                        {
                            "学号": info.get("xh") or self.username,
                            "姓名": info.get("xm") or "",
                            "性别": info.get("xbm") or "",
                            "学院": info.get("zsjg_id") or info.get("jg_id") or info.get("jgmc") or "",
                            "专业": info.get("zszyh_id") or info.get("zyh_id") or info.get("zymc") or "",
                            "班级": info.get("bh_id") or info.get("bjmc") or "",
                            "年级": info.get("njdm_id") or info.get("njmc") or "",
                            "学籍状态": info.get("xjztdm") or "",
                            "培养层次": info.get("pyccdm") or "",
                            "入学日期": info.get("rxrq") or "",
                        }
                    )
        except Exception:
            pass

        # 若 JSON 接口未返回部分字段，从页面解析字段补齐
        raw_map = profile.get("页面解析字段", {})
        if isinstance(raw_map, dict) and raw_map:
            profile.setdefault("学号", raw_map.get("学号") or self.username)
            profile.setdefault("姓名", raw_map.get("姓名") or "")
            profile.setdefault("学院", raw_map.get("学院名称") or raw_map.get("学院") or "")
            profile.setdefault("专业", raw_map.get("专业名称") or raw_map.get("专业") or "")
            profile.setdefault("班级", raw_map.get("班级名称") or raw_map.get("行政班") or "")
            profile.setdefault("年级", raw_map.get("年级") or raw_map.get("所在年级") or "")
            profile.setdefault("学籍状态", raw_map.get("学籍状态") or "")
            profile.setdefault("培养层次", raw_map.get("培养层次") or "")

        return profile

    def fetch_raw_grades(
        self,
        academic_year: str = "",
        term: str = "",
    ) -> List[Dict[str, Any]]:
        """
        抓取【查询个人信息 -> 成绩信息】（以及【信息查询 -> 学生成绩查询】）数据。
        默认先按传入的学年/学期查询；若传入为空或当前未出分，支持拉取全部历年成绩。
        """
        xnm = str(academic_year).strip() if academic_year else ""
        xqm = self._resolve_term_code(term) if term else ""

        # 候选接口：涵盖“查询个人信息-成绩信息”接口与“学生成绩查询”接口
        candidate_endpoints: List[Tuple[str, str]] = [
            (f"{self.base_url}/xsxxxggl/xsxxwh_cxXscjxx.html?gnmkdm=N100801", "N100801"),
            (f"{self.base_url}/cjcx/cjcx_cxDgXscj.html?doType=query&gnmkdm=N100801", "N100801"),
            (f"{self.base_url}/cjcx/cjcx_cxDgXscj.html?doType=query&gnmkdm=N305005", "N305005"),
            (f"{self.base_url}/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005", "N305005"),
        ]

        def _query_once(q_xnm: str, q_xqm: str) -> Optional[List[Dict[str, Any]]]:
            payload = {
                "xnm": q_xnm,
                "xqm": q_xqm,
                "_search": "false",
                "nd": str(int(time.time() * 1000)),
                "queryModel.showCount": "5000",
                "queryModel.currentPage": "1",
                "queryModel.sortName": "",
                "queryModel.sortOrder": "asc",
                "time": "1",
            }
            for endpoint, gnmkdm in candidate_endpoints:
                headers = {
                    "X-Requested-With": "XMLHttpRequest",
                    "Referer": f"{self.base_url}/xsxxxggl/xsgrxxwh_cxXsgrxx.html?gnmkdm={gnmkdm}&layout=default",
                    "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
                    "Accept": "application/json, text/javascript, */*; q=0.01",
                }
                try:
                    resp = self.session.post(
                        endpoint,
                        data=payload,
                        headers=headers,
                        timeout=self.timeout,
                    )
                    if resp.status_code != 200:
                        continue
                    data = resp.json()
                    if isinstance(data, dict) and "items" in data and isinstance(data["items"], list):
                        return data["items"]
                    if isinstance(data, list):
                        return data
                except Exception:
                    continue
            return None

        items = _query_once(xnm, xqm)
        # 如果指定了当前学期但尚未出分（返回空列表），自动回退查询该生全部历史成绩
        if items is not None and len(items) == 0 and (xnm or xqm):
            all_items = _query_once("", "")
            if all_items:
                return all_items

        if items is None:
            raise RuntimeError("获取成绩信息 JSON 失败，请检查登录状态或教务系统权限。")
        return items

    @staticmethod
    def parse_grade_items(raw_items: List[Dict[str, Any]]) -> Dict[str, Any]:
        """解析【成绩信息】条目并计算统计摘要（总学分、平均绩点等）"""
        parsed_grades: List[Dict[str, Any]] = []
        total_credits = 0.0
        weighted_gp_sum = 0.0
        gp_course_count = 0

        for item in raw_items:
            course_name = (item.get("kcmc") or "").strip()
            score = str(item.get("cj") or item.get("bfzcj") or "").strip()
            credit_str = str(item.get("xf") or "").strip()
            gp_str = str(item.get("jd") or "").strip()

            try:
                credit_val = float(credit_str) if credit_str else 0.0
            except ValueError:
                credit_val = 0.0

            try:
                gp_val = float(gp_str) if gp_str else None
            except ValueError:
                gp_val = None

            if credit_val > 0 and gp_val is not None:
                total_credits += credit_val
                weighted_gp_sum += credit_val * gp_val
                gp_course_count += 1

            parsed_grades.append(
                {
                    "课程名称": course_name,
                    "课程号": (item.get("kch") or item.get("kch_id") or "").strip(),
                    "成绩": score,
                    "绩点": gp_str,
                    "学分": credit_str,
                    "课程性质": (item.get("kcxzmc") or "").strip(),
                    "课程类别": (item.get("kclbmc") or "").strip(),
                    "考核方式": (item.get("khfsmc") or "").strip(),
                    "考试性质": (item.get("ksxz") or item.get("ksxzmc") or "正常考试").strip(),
                    "任课教师": (item.get("jsxm") or "").strip(),
                    "教学班": (item.get("jxbmc") or "").strip(),
                    "开课学院": (item.get("kkbmmc") or "").strip(),
                    "学年": (item.get("xnmmc") or str(item.get("xnm") or "")).strip(),
                    "学期": (item.get("xqmmc") or str(item.get("xqm") or "")).strip(),
                    "成绩备注": (item.get("cjbz") or "").strip(),
                }
            )

        weighted_gpa = round(weighted_gp_sum / total_credits, 3) if total_credits > 0 else 0.0
        return {
            "成绩记录总数": len(parsed_grades),
            "纳入绩点统计课程数": gp_course_count,
            "统计总学分": round(total_credits, 2),
            "加权平均绩点(GPA)": weighted_gpa,
            "成绩列表": parsed_grades,
        }

    def fetch_raw_selected_courses(
        self,
        academic_year: str = "2026",
        term: str = "1",
    ) -> List[Dict[str, Any]]:
        """
        抓取【查询个人信息 -> 选课信息】（以及【选课名单查询 / 自主选课已选课程】）数据。
        优先请求个人信息页下的 `xsxxxggl/xsxxwh_cxXsxkxx.html?gnmkdm=N100801`，
        并兼容选课查询 `xkcx/xkmdcx_cxXkmdcxIndex.html` 与自主选课 `xsxk/zzxkyzb_cxZzxkYzbChoosedDisplay.html`。
        """
        xnm = str(academic_year).strip() if academic_year else ""
        xqm = self._resolve_term_code(term) if term else ""

        # 候选分页查询接口（查询个人信息-选课信息 & 信息查询-选课名单查询）
        paginated_endpoints: List[Tuple[str, str]] = [
            (f"{self.base_url}/xsxxxggl/xsxxwh_cxXsxkxx.html?gnmkdm=N100801", "N100801"),
            (f"{self.base_url}/xsxxxggl/xsgrxxwh_cxXsxkxx.html?gnmkdm=N100801", "N100801"),
            (f"{self.base_url}/xkcx/xkmdcx_cxXkmdcxIndex.html?doType=query&gnmkdm=N255005", "N255005"),
        ]

        def _query_paginated(q_xnm: str, q_xqm: str) -> Optional[List[Dict[str, Any]]]:
            payload = {
                "xnm": q_xnm,
                "xqm": q_xqm,
                "_search": "false",
                "nd": str(int(time.time() * 1000)),
                "queryModel.showCount": "5000",
                "queryModel.currentPage": "1",
                "queryModel.sortName": "",
                "queryModel.sortOrder": "asc",
                "time": "1",
            }
            for endpoint, gnmkdm in paginated_endpoints:
                headers = {
                    "X-Requested-With": "XMLHttpRequest",
                    "Referer": f"{self.base_url}/xsxxxggl/xsgrxxwh_cxXsgrxx.html?gnmkdm={gnmkdm}&layout=default",
                    "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
                    "Accept": "application/json, text/javascript, */*; q=0.01",
                }
                try:
                    resp = self.session.post(
                        endpoint,
                        data=payload,
                        headers=headers,
                        timeout=self.timeout,
                    )
                    if resp.status_code != 200:
                        continue
                    data = resp.json()
                    if isinstance(data, dict) and "items" in data and isinstance(data["items"], list):
                        return data["items"]
                    if isinstance(data, list):
                        return data
                except Exception:
                    continue
            return None

        items = _query_paginated(xnm, xqm)
        if items is not None and len(items) == 0 and (xnm or xqm):
            all_items = _query_paginated("", "")
            if all_items:
                return all_items

        if items is not None:
            return items

        # 备用接口：自主选课已选课程展示接口 (N253512)
        choosed_url = f"{self.base_url}/xsxk/zzxkyzb_cxZzxkYzbChoosedDisplay.html?gnmkdm=N253512"
        try:
            resp_choosed = self.session.post(
                choosed_url,
                data={"xkxnm": xnm or "2026", "xkxqm": xqm or "3"},
                headers={
                    "X-Requested-With": "XMLHttpRequest",
                    "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
                    "Accept": "application/json, text/javascript, */*; q=0.01",
                },
                timeout=self.timeout,
            )
            if resp_choosed.status_code == 200:
                choosed_data = resp_choosed.json()
                if isinstance(choosed_data, list):
                    return choosed_data
                if isinstance(choosed_data, dict) and isinstance(choosed_data.get("items"), list):
                    return choosed_data["items"]
        except Exception as exc:
            raise RuntimeError(f"获取选课信息 JSON 失败: {exc}") from exc

        raise RuntimeError("获取选课信息 JSON 失败，请检查登录状态或教务系统权限。")

    @staticmethod
    def parse_selected_course_items(raw_items: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        解析【查询个人信息 -> 选课信息】返回的选课记录。
        兼容个人信息选课表字段 (jsxm, kcmc, sksj, jxdd) 与自主选课字段 (jsxx)。
        """
        parsed_selected: List[Dict[str, Any]] = []

        for item in raw_items:
            course_name = (item.get("kcmc") or "").strip()

            # 解析教师姓名（兼容 jsxm 直接字段 与 jsxx "工号/姓名/职称" 格式）
            teacher = (item.get("jsxm") or item.get("xm") or "").strip()
            jsxx = (item.get("jsxx") or "").strip()
            if not teacher and jsxx:
                parts = [p.strip() for p in jsxx.split("/") if p.strip()]
                teacher = parts[1] if len(parts) >= 2 else parts[0]

            # 清洗时间与地点中的 <br/> 标签
            raw_time = (item.get("sksj") or "").strip()
            clean_time = "；".join(
                [seg.strip() for seg in re.split(r"<br\s*/?>", raw_time) if seg.strip()]
            )

            raw_place = (item.get("jxdd") or item.get("cdmc") or "").strip()
            clean_place = "；".join(
                [seg.strip() for seg in re.split(r"<br\s*/?>", raw_place) if seg.strip()]
            )

            parsed_selected.append(
                {
                    "课程名称": course_name,
                    "课程号": (item.get("kch") or item.get("kch_id") or "").strip(),
                    "教学班": (item.get("jxbmc") or item.get("jxb_id") or "").strip(),
                    "老师": teacher or "未公布",
                    "时间": clean_time,
                    "地点": clean_place,
                    "学分": str(item.get("xf") or "").strip(),
                    "课程类别": (item.get("kclbmc") or item.get("kklxmc") or "").strip(),
                    "课程性质": (item.get("kcxzmc") or "").strip(),
                    "开课学院": (item.get("kkbmmc") or item.get("kkxymc") or "").strip(),
                    "学年": (item.get("xnmmc") or str(item.get("xnm") or item.get("xkxnm") or "")).strip(),
                    "学期": (item.get("xqmmc") or str(item.get("xqm") or item.get("xkxqm") or "")).strip(),
                    "选课状态": (
                        item.get("xkztmc")
                        or ("已选上" if str(item.get("sxbj")) == "1" else str(item.get("sxbj") or "已选"))
                    ).strip(),
                    "是否重修": "是" if str(item.get("cxbj")) == "1" else "否",
                }
            )

        return {
            "选课记录总数": len(parsed_selected),
            "选课列表": parsed_selected,
        }

    # =========================================================================
    # 综合抓取与 JSON 导出入口
    # =========================================================================
    def crawl_and_export(
        self,
        academic_year: str = "2026",
        term: str = "1",
        all_grades: bool = True,
        output_path: str = "haut_student_data.json",
        cookie_str: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        完整执行登录、抓取【个人课表查询 + 查询个人信息（含学籍、成绩信息、选课信息）】并导出 JSON。
        :param academic_year: 课表与选课查询的默认学年（如 "2026" 代表 2026-2027 学年）
        :param term: 课表与选课查询的默认学期（"1"=第一学期, "2"=第二学期, "3"=第三学期）
        :param all_grades: 是否默认抓取全部学年学期的成绩信息（True=全部学年，False=仅当前指定学年学期）
        :param output_path: 导出的 JSON 文件路径
        :param cookie_str: 浏览器 Cookie 字符串（可选）
        """
        if cookie_str:
            print("[*] 使用提供的 Cookie 初始化会话...")
            self.set_cookie_string(cookie_str)
        else:
            print(f"[*] 正在登录河南工业大学教务系统 (学号: {self.username})...")
            self.login()
            print("[+] 登录成功！")

        # 1. 抓取个人课表查询信息
        print(f"[*] 正在抓取【个人课表查询】 ({academic_year}-{int(academic_year) + 1} 学年 第 {term} 学期)...")
        raw_schedule = self.fetch_raw_schedule(academic_year=academic_year, term=term)
        schedule_result = self.parse_schedule_items(raw_schedule)

        # 2. 抓取查询个人信息 - 学籍基本信息
        print("[*] 正在抓取【查询个人信息 - 学籍与基本信息】...")
        personal_profile = self.fetch_personal_profile()
        xsxx = raw_schedule.get("xsxx") or {}
        if xsxx:
            personal_profile.setdefault("学号", xsxx.get("XH") or self.username)
            personal_profile.setdefault("姓名", xsxx.get("XM") or "")
            personal_profile.setdefault("班级", xsxx.get("BJMC") or "")

        # 3. 抓取查询个人信息 - 成绩信息
        grade_year = "" if all_grades else academic_year
        grade_term = "" if all_grades else term
        scope_desc = "全部学年学期" if all_grades else f"{academic_year}-{int(academic_year) + 1} 学年 第 {term} 学期"
        print(f"[*] 正在抓取【查询个人信息 - 成绩信息】 ({scope_desc})...")
        raw_grades = self.fetch_raw_grades(academic_year=grade_year, term=grade_term)
        grades_result = self.parse_grade_items(raw_grades)

        # 4. 抓取查询个人信息 - 选课信息
        print(f"[*] 正在抓取【查询个人信息 - 选课信息】 ({academic_year}-{int(academic_year) + 1} 学年 第 {term} 学期)...")
        raw_selected = self.fetch_raw_selected_courses(academic_year=academic_year, term=term)
        selected_result = self.parse_selected_course_items(raw_selected)

        export_payload = {
            "元数据": {
                "学校": "河南工业大学",
                "系统": "正方教学综合信息服务平台 N9 (V-9.0)",
                "教务网址": self.base_url,
                "查询学年": f"{academic_year}-{int(academic_year) + 1}",
                "查询学期": str(term),
                "抓取时间": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()),
            },
            "个人课表查询信息": schedule_result,
            "查询个人信息": {
                "学籍基本信息": personal_profile,
                "成绩信息": grades_result,
                "选课信息": selected_result,
            },
        }

        out_file = Path(output_path)
        out_file.parent.mkdir(parents=True, exist_ok=True)
        out_file.write_text(
            json.dumps(export_payload, ensure_ascii=False, indent=4),
            encoding="utf-8",
        )
        print(
            f"[+] 全部数据抓取完成！\n"
            f"    - 个人课表: {schedule_result['课程总数']} 门排课\n"
            f"    - 成绩信息: {grades_result['成绩记录总数']} 条成绩记录 (GPA: {grades_result['加权平均绩点(GPA)']})\n"
            f"    - 选课信息: {selected_result['选课记录总数']} 条选课记录\n"
            f"    - 导出文件: {out_file.resolve()}"
        )
        return export_payload


def main() -> None:
    parser = argparse.ArgumentParser(
        description="河南工业大学正方教务系统（jwglxt.haut.edu.cn）课表、成绩与选课信息综合爬虫"
    )
    parser.add_argument(
        "-u", "--username", default="251210100701", help="学号（默认: 251210100701）"
    )
    parser.add_argument(
        "-p", "--password", default="Csy1230！", help="教务系统密码（默认已预填）"
    )
    parser.add_argument(
        "-y",
        "--year",
        default="2026",
        help="学年起始年份，例如 2025 表示 2025-2026 学年，2026 表示 2026-2027 学年（默认: 2026）",
    )
    parser.add_argument(
        "-t",
        "--term",
        default="1",
        choices=["1", "2", "3", "12", "16", "all"],
        help="学期：1=第一学期(秋), 2=第二学期(春), 3=第三学期(夏), all=全部学期（默认: 1）",
    )
    parser.add_argument(
        "--current-term-grades-only",
        action="store_true",
        help="仅查询指定学年学期的成绩（默认拉取全部历史学年学期的成绩信息）",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="haut_student_data.json",
        help="导出的 JSON 文件路径（默认: haut_student_data.json）",
    )
    parser.add_argument(
        "--cookie",
        default=None,
        help="可选：浏览器登录后的 Cookie 字符串（如 JSESSIONID=xxx; route=xxx），用于跳过密码登录",
    )
    parser.add_argument(
        "--ascii-bang",
        action="store_true",
        help="将密码末尾的全角感叹号“！”自动替换为英文半角“!”",
    )

    args = parser.parse_args()
    password = args.password.replace("！", "!") if args.ascii_bang else args.password
    all_grades = not args.current_term_grades_only

    spider = HAUTJwglxtSpider(username=args.username, password=password)
    try:
        spider.crawl_and_export(
            academic_year=args.year,
            term=args.term,
            all_grades=all_grades,
            output_path=args.output,
            cookie_str=args.cookie,
        )
    except Exception as exc:
        # 若密码末尾含中文全角感叹号“！”导致登录失败，自动尝试英文半角“!”
        if (
            not args.cookie
            and "！" in password
            and ("用户名或密码不正确" in str(exc) or "登录失败" in str(exc))
        ):
            print("[!] 使用全角感叹号“！”登录未通过，正在自动尝试英文半角感叹号“!”...")
            spider.password = password.replace("！", "!")
            try:
                spider.crawl_and_export(
                    academic_year=args.year,
                    term=args.term,
                    all_grades=all_grades,
                    output_path=args.output,
                    cookie_str=args.cookie,
                )
                return
            except Exception as retry_exc:
                print(f"[x] 运行出错: {retry_exc}", file=sys.stderr)
                sys.exit(1)

        print(f"[x] 运行出错: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()