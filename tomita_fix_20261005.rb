# encoding: UTF-8
# =============================================================================
# 富田複合施設3D 修正スクリプト（対象: 富田複合施設3D_自動生成_20261005_修正3.skp）
#
#  STEP A  南側吹抜け（1F→2F）と吹抜け内の南東階段を、20260918案の図面どおりに追加
#          - 2F床スラブ / 2F床(ナラ) / 1F天井 / 2Fテラスデッキ に吹抜け開口を開ける
#          - 吹抜け内の 1F→2F 階段（3連・踊り場2か所）を新規作成
#          - 吹抜け周りと階段の手摺（ガラス＋笠木）を新規作成
#          - 1F 南東部の間仕切（会議室1〜3）を撤去し、プレイルーム1の一室空間にする
#          - 室名を図面に合わせて修正（2F テラス→出会いホール 等）
#  STEP B  階ごとのタグ（レイヤー）を作成し、全要素を 1F/2F/3F/RF/複数階 に振り分け
#          - 既存の「部位別タグ」（01_構造… 等）は親グループ側に残すので、
#            部位別・階別のどちらでも表示/非表示を切り替えられる
#
# 使い方:
#   1. 元の .skp を必ず別名でバックアップしてから開く
#   2. [拡張機能]→[Ruby コンソール] を開き、次を入力して Enter
#        load 'C:/temp/tomita_fix_20261005.rb'
#      ※ このファイルは日本語を含まないフォルダ（例: C:/temp）に置くと確実です
#      （このファイルを読み込むと STEP A → STEP B の順で自動実行されます）
#      個別に実行したい場合は、先頭の AUTO_RUN を false にして読み込み後に
#        TomitaFix.step_a_south_void   /   TomitaFix.step_b_floor_tags
#   3. 結果が気に入らなければ [編集]→[元に戻す] を2回（STEP B → STEP A の順）で元に戻ります
#
# 座標の根拠（すべて mm、モデル原点 = 通り芯 X0/Y0・1FL±0、X=東、Y=北）:
#   - モデル内に取り込まれている「20260918_複合施設プラン検討案 for su01.dwg」の
#     柱芯をモデルの柱芯に合わせて読み取った値（ずれ 0mm で一致を確認済み）
#   - 吹抜け : X 15,950〜37,350 / Y -150〜5,650（2F平面の吹抜け×印の範囲）
#   - 階段   : 段鼻線 300 ピッチ、1F→2F（階高5,000）を35段で上る
#               1段目 X27,250→X30,250（11段）、中間踊り場 X30,250〜32,250、
#               2段目 X32,250→X35,250（11段）、コーナー踊り場 X35,250〜37,250、
#               3段目 Y1,950→Y5,550（13段）で 2F に到達、幅 2,000
#               蹴上げ = 5,000 / 35 ≒ 142.9mm、踏面 300mm
# =============================================================================

module TomitaFix
  AUTO_RUN = true

  # ---- 階の設定（mm） -------------------------------------------------------
  FL = { '1F' => 0.0, '2F' => 5000.0, '3F' => 9500.0, 'RF' => 14000.0 }.freeze
  # 床スラブ・床梁を上階側に含めるため、各階の判定開始を FL-900 とする
  # （例: 2F床梁の下端 4,100 は 2F、1F天井 4,000 は 1F）
  BAND_OFFSET = 900.0
  # 要素の上端が「次の階の判定開始 + 2,500」を超えたら複数階にまたがる部材とみなす
  # （1F→2F 階段の手摺上端 6,100 は 1F、通し柱 0〜14,000 は複数階）
  SPAN_TOL = 2500.0

  TAG_FOLDER = '階別'.freeze
  FLOOR_TAGS = {
    '1F'    => ['1F',            [ 66, 133, 244]],
    '2F'    => ['2F',            [ 52, 168,  83]],
    '3F'    => ['3F',            [251, 188,   5]],
    'RF'    => ['RF_屋根',        [234,  67,  53]],
    'MULTI' => ['複数階_通し部材', [128, 128, 128]]
  }.freeze
  # これらのタグは「未分類」とみなし、階別タグで上書きしてよい
  DEFAULT_TAG_NAMES = ['Layer0', 'タグなし00'].freeze

  BUILDING_PREFIX = '富田複合施設_3D'.freeze
  # 名前で階が明示されているグループ（とその中身）は、高さだけでは判断が分かれる
  # 「次の階の FL 直下（FL-900〜FL）」の要素をその名前の階に入れる
  # （例: 「1F 下屋」東側の瓦 4,820〜5,200 → 1F。ただし同グループ内の
  #   最上階レベルの梁 13,200〜13,650 は高さどおり RF）
  NAME_FLOOR_RULES = [[/\A1F[ _]/, '1F'], [/\A2F[ _]/, '2F'], [/\A3F[ _]/, '3F'], [/\A風除室/, '1F']].freeze
  SKIP_PREFIXES   = ['外構'].freeze # 外構は既存の 10_外構・植栽 タグのまま

  # ---- 南側吹抜け・階段（mm） ------------------------------------------------
  VOID = { x0: 15_950.0, y0: -150.0, x1: 37_350.0, y1: 5_650.0 }.freeze
  RISER  = 5000.0 / 35.0
  TREAD  = 300.0
  STAIR_W = 2000.0
  WAIST   = 180.0   # 階段スラブ厚（段裏）
  LANDING_T = 200.0 # 踊り場スラブ厚
  RAIL_H  = 1100.0  # 手摺高さ
  GLASS_T = 15.0
  CAP_W   = 50.0
  CAP_H   = 40.0

  MARK_DICT = 'TomitaFix'.freeze

  module_function

  # ===========================================================================
  # 共通ヘルパー
  # ===========================================================================
  def model
    Sketchup.active_model
  end

  def pt(x, y, z)
    Geom::Point3d.new(x.to_f.mm, y.to_f.mm, z.to_f.mm)
  end

  def mat(name)
    model.materials[name]
  end

  def container?(e)
    e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
  end

  # 名前一致のグループ/コンポーネントを再帰検索し [entity, world_transformation] を返す
  def find_named(name, ents = model.entities, tr = Geom::Transformation.new, out = [], seen = {})
    ents.each do |e|
      next unless container?(e)
      t = tr * e.transformation
      out << [e, t] if e.name == name
      key = e.definition.entityID
      next if seen[key] && !e.is_a?(Sketchup::Group)
      seen[key] = true
      find_named(name, e.definition.entities, t, out, seen)
    end
    out
  end

  def find_one(name)
    hits = find_named(name)
    raise "グループ「#{name}」が見つかりません" if hits.empty?
    puts "  注意: 「#{name}」が #{hits.size} 個あります。最初の1つを使用します。" if hits.size > 1
    hits.first
  end

  def find_texts(ents = model.entities, tr = Geom::Transformation.new, out = [])
    ents.each do |e|
      if e.is_a?(Sketchup::Text)
        out << [e, tr]
      elsif e.is_a?(Sketchup::Group)
        find_texts(e.definition.entities, tr * e.transformation, out)
      end
    end
    out
  end

  # entity の bounds（親座標）を world に変換した [min, max]（mm）
  def world_bb_mm(ent, parent_tr)
    if ent.is_a?(Sketchup::Text)
      p = ent.point.transform(parent_tr)
      v = [p.x.to_mm, p.y.to_mm, p.z.to_mm]
      return [v, v]
    end
    bb = ent.bounds
    return nil if bb.empty?
    mn = [Float::INFINITY] * 3
    mx = [-Float::INFINITY] * 3
    8.times do |i|
      c = bb.corner(i).transform(parent_tr)
      [c.x.to_mm, c.y.to_mm, c.z.to_mm].each_with_index do |v, k|
        mn[k] = v if v < mn[k]
        mx[k] = v if v > mx[k]
      end
    end
    [mn, mx]
  end

  # 平面ポリゴン pts を vec 方向に押し出した閉じたソリッドを ents に作る。
  # 面の向き（表/裏）は外向きになるよう明示的にそろえる。
  def prism(ents, pts, vec, material = nil)
    n = pts.size
    # Newell 法でポリゴン法線（反時計回りの向き）を求める
    nx = ny = nz = 0.0
    n.times do |i|
      a = pts[i]
      b = pts[(i + 1) % n]
      nx += (a.y - b.y) * (a.z + b.z)
      ny += (a.z - b.z) * (a.x + b.x)
      nz += (a.x - b.x) * (a.y + b.y)
    end
    nrm = Geom::Vector3d.new(nx, ny, nz)
    nrm.normalize!
    top = pts.map { |p| p.offset(vec) }
    faces = []
    f = ents.add_face(pts)
    faces << [f, vec.reverse]
    f = ents.add_face(top)
    faces << [f, vec]
    n.times do |i|
      j = (i + 1) % n
      edge = pts[i].vector_to(pts[j])
      out = edge.cross(nrm) # 反時計回りの辺 × 法線 = 外向き
      f = ents.add_face(pts[i], pts[j], top[j], top[i])
      faces << [f, out]
    end
    faces.each do |face, want|
      next unless face
      face.reverse! if face.normal.dot(want) < 0
      if material
        face.material = material
        face.back_material = material
      end
    end
    faces.map(&:first)
  end

  def box(ents, x0, y0, z0, x1, y1, z1, material = nil)
    prism(ents, [pt(x0, y0, z0), pt(x1, y0, z0), pt(x1, y1, z0), pt(x0, y1, z0)],
          Geom::Vector3d.new(0, 0, (z1 - z0).mm), material)
  end

  def inside_rect?(p, r, tol = 1.0)
    x = p.x.to_mm
    y = p.y.to_mm
    x >= r[:x0] - tol && x <= r[:x1] + tol && y >= r[:y0] - tol && y <= r[:y1] + tol
  end

  def clip_rect(r, bb_local)
    x0 = [r[:x0], bb_local.min.x.to_mm].max
    y0 = [r[:y0], bb_local.min.y.to_mm].max
    x1 = [r[:x1], bb_local.max.x.to_mm].min
    y1 = [r[:y1], bb_local.max.y.to_mm].min
    return nil if x1 - x0 < 1.0 || y1 - y0 < 1.0
    { x0: x0, y0: y0, x1: x1, y1: y1 }
  end

  # world 座標の矩形を、グループのローカル座標の矩形に変換（回転なし前提）
  def rect_to_local(r, tr)
    inv = tr.inverse
    a = pt(r[:x0], r[:y0], 0).transform(inv)
    b = pt(r[:x1], r[:y1], 0).transform(inv)
    { x0: [a.x, b.x].min.to_mm, y0: [a.y, b.y].min.to_mm,
      x1: [a.x, b.x].max.to_mm, y1: [a.y, b.y].max.to_mm }
  end

  def rect_pts(r, z_mm)
    [pt(r[:x0], r[:y0], z_mm), pt(r[:x1], r[:y0], z_mm),
     pt(r[:x1], r[:y1], z_mm), pt(r[:x0], r[:y1], z_mm)]
  end

  def horizontal_at?(face, z_mm, tol = 1.0)
    face.normal.z.abs > 0.999 && (face.vertices.first.position.z.to_mm - z_mm).abs < tol
  end

  def erase_faces_inside(ents, r, z_mm)
    dead = ents.grep(Sketchup::Face).select do |f|
      horizontal_at?(f, z_mm) && f.vertices.all? { |v| inside_rect?(v.position, r) }
    end
    ents.erase_entities(dead) unless dead.empty?
    stray = ents.grep(Sketchup::Edge).select do |e|
      e.faces.empty? && e.vertices.all? { |v| inside_rect?(v.position, r) && (v.position.z.to_mm - z_mm).abs < 1.0 }
    end
    ents.erase_entities(stray) unless stray.empty?
    dead.size
  end

  def unique!(grp)
    grp.make_unique if grp.is_a?(Sketchup::Group) && grp.definition.count_instances > 1
  end

  # ===========================================================================
  # STEP A: 南側吹抜け・階段
  # ===========================================================================
  def step_a_south_void
    if model.get_attribute(MARK_DICT, 'south_void_done')
      UI.messagebox('STEP A は既に実行済みです（二重実行を防止しました）。')
      return
    end
    model.start_operation('南側吹抜け・南東階段の追加', true)
    log = []

    # --- A1. 2F 床スラブ（厚みのあるソリッド）に開口 ---
    slab, tr = find_one('2F 床スラブ(吹抜・階段開口)')
    unique!(slab)
    ents = slab.definition.entities
    r = rect_to_local(VOID, tr)
    lbb = slab.definition.bounds
    zt = lbb.max.z.to_mm
    zb = lbb.min.z.to_mm
    slab_mat = ents.grep(Sketchup::Face).map(&:material).compact.first || mat('13_コンクリート')
    ents.add_face(rect_pts(r, zt))
    ents.add_face(rect_pts(r, zb))
    t = rect_pts(r, zt)
    b = rect_pts(r, zb)
    4.times do |i|
      j = (i + 1) % 4
      f = ents.add_face(b[i], b[j], t[j], t[i])
      next unless f
      # 開口の側面は開口の内側（＝吹抜け側）を向ける
      c = Geom::Point3d.new((r[:x0] + r[:x1]) / 2.0 * 1.mm, (r[:y0] + r[:y1]) / 2.0 * 1.mm, f.vertices.first.position.z)
      to_center = f.vertices.first.position.vector_to(c)
      to_center.z = 0
      f.reverse! if f.normal.dot(to_center) < 0
      f.material = slab_mat
    end
    n1 = erase_faces_inside(ents, r, zt)
    n2 = erase_faces_inside(ents, r, zb)
    log << "2F床スラブに吹抜け開口（上面#{n1}面・下面#{n2}面を除去）"

    # --- A2. 仕上げ面（単一面）に開口: 2F床(ナラ)・1F天井・テラスデッキ(2F面のみ) ---
    [['2F 床 (ナラ)', nil], ['1F 天井', nil], ['テラス ウッドデッキ', 5008.0]].each do |name, zsel|
      hits = find_named(name)
      if hits.empty?
        log << "（スキップ）「#{name}」なし"
        next
      end
      g, gtr = hits.first
      unique!(g)
      gents = g.definition.entities
      rr = rect_to_local(VOID, gtr)
      zlocal_sel = zsel && pt(0, 0, zsel).transform(gtr.inverse).z.to_mm
      targets = gents.grep(Sketchup::Face).select do |f|
        f.normal.z.abs > 0.999 &&
          (zlocal_sel.nil? || (f.vertices.first.position.z.to_mm - zlocal_sel).abs < 1.0)
      end
      jobs = targets.map { |f| [f.vertices.first.position.z.to_mm, clip_rect(rr, f.bounds)] }.select { |_, c| c }
      cnt = 0
      jobs.each do |z, c|
        gents.add_face(rect_pts(c, z))
        cnt += erase_faces_inside(gents, c, z)
      end
      log << "「#{name}」に開口（#{cnt}面を除去）"
    end

    # --- A3. 1F 南東部の間仕切撤去（会議室1〜3の壁・扉。プレイルーム1を一室に） ---
    part, ptr = find_one('1F 間仕切・建具')
    unique!(part)
    dead = []
    part.definition.entities.each do |e|
      next unless container?(e)
      mn, mx = world_bb_mm(e, ptr)
      next unless mn
      # X29,800〜37,400 / Y-200〜22,360 の範囲に収まり、北側境界壁（Y≒22,350）ではないもの
      next unless mn[0] >= 29_800 && mx[0] <= 37_400 && mn[1] >= -200 && mx[1] <= 22_360
      next if mn[1] >= 22_280
      dead << e
    end
    part.definition.entities.erase_entities(dead) unless dead.empty?
    log << "1F南東部の間仕切・扉 #{dead.size}要素を撤去"

    # --- A4. 南東階段（1F→2F）を新規作成 ---
    host, htr = (find_named('階段 (室内)').first || find_one(BUILDING_PREFIX_NAME_FALLBACK))
    unique!(host)
    sg = host.definition.entities.add_group
    sg.name = '南東階段 1F→2F（南側吹抜け内）'
    sg.transformation = htr.inverse # 以降は world 座標(mm)でそのまま描ける
    se = sg.entities
    tread_mat = mat('46_階段_段板')
    h = RISER
    flight(se, [27_250.0, -50.0], :x, 0.0, 11, tread_mat)          # 1段目
    box(se, 30_250, -50, 11 * h - LANDING_T, 32_250, 1_950, 11 * h, tread_mat) # 中間踊り場
    flight(se, [32_250.0, -50.0], :x, 11 * h, 11, tread_mat)       # 2段目
    box(se, 35_250, -50, 22 * h - LANDING_T, 37_250, 1_950, 22 * h, tread_mat) # コーナー踊り場
    flight(se, [35_250.0, 1_950.0], :y, 22 * h, 13, tread_mat)     # 3段目
    box(se, 35_250, 5_550, 35 * h - LANDING_T, 37_250, 5_650, 35 * h, tread_mat) # 2F取合い
    log << '南東階段（35段・蹴上≒142.9・踏面300・幅2,000）を作成'

    # --- A5. 手摺（ガラス＋笠木） ---
    gl = mat('11_手摺ガラス')
    cap = mat('59_手摺_白')
    # 階段の手摺（1F 扱い）と 2F 吹抜け周りの手摺（2F 扱い）は別グループにする
    rg = host.definition.entities.add_group
    rg.name = '南東階段 手摺'
    rg.transformation = htr.inverse
    # 階段1・2段目の北側（吹抜け側）: 段鼻線に沿う
    guard(rg.entities, [[27_250, 1_920, h], [30_250, 1_920, 11 * h], [32_250, 1_920, 11 * h], [35_250, 1_920, 22 * h]], gl, cap)
    # 階段3段目の西側
    guard(rg.entities, [[35_280, 1_920, 22 * h], [35_280, 5_550, 35 * h], [35_280, 5_650, 35 * h]], gl, cap)
    vg = host.definition.entities.add_group
    vg.name = '南側吹抜け 手摺(2F)'
    vg.transformation = htr.inverse
    # 2F 吹抜け北辺（階段着床部を除く）・西辺
    guard(vg.entities, [[15_950, 5_690, 5_000], [35_250, 5_690, 5_000]], gl, cap)
    guard(vg.entities, [[15_910, -150, 5_000], [15_910, 5_690, 5_000]], gl, cap)
    log << '吹抜け周り・階段の手摺を作成'

    # --- A6. 室名の修正 ---
    texts = find_texts
    rename = {
      '1F 多世代交流スペース' => ['1F プレイルーム1', nil],
      '2F テラス'             => ['2F 出会いホール', [10_400, 2_800, 6_500]]
    }
    texts.each do |tx, ttr|
      if rename.key?(tx.text)
        new_name, pos = rename[tx.text]
        log << "室名「#{tx.text}」→「#{new_name}」"
        tx.text = new_name
        tx.point = pt(*pos).transform(ttr.inverse) if pos
      end
    end
    removed = texts.select { |tx, _| ['1F 会議室1', '1F 会議室2', '1F 会議室3'].include?(tx.text) }
    removed.each { |tx, _| tx.erase! }
    log << "室名「1F 会議室1〜3」を削除（#{removed.size}件）" unless removed.empty?
    label_host = find_named('室名').first
    if label_host
      lg, ltr = label_host
      unique!(lg)
      lg.definition.entities.add_text('2F 吹抜け(南側 1F～2F)', pt(26_650, 2_750, 6_500).transform(ltr.inverse))
      log << '室名「2F 吹抜け(南側 1F～2F)」を追加'
    end

    model.set_attribute(MARK_DICT, 'south_void_done', true)
    model.commit_operation
    puts "[STEP A 完了]\n  " + log.join("\n  ")
    log
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP A でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
  end
  BUILDING_PREFIX_NAME_FALLBACK = '富田複合施設_3D (原点=通り芯X0/Y0, 1FL±0)'.freeze

  # 階段1連（段板＋段裏スラブを一体の側面形状として幅方向に押し出し）
  #   base: 1段目の蹴込み位置と階段の端（world mm）
  #   dir : :x（東へ上る、幅は北へ）または :y（北へ上る、幅は東へ）
  #   n   : 蹴上げ数（最後の蹴上げで上の踊り場/床の高さに達する）
  def flight(ents, base, dir, z0, n, material)
    h = RISER
    t = TREAD
    wp = WAIST * Math.sqrt(1.0 + (h / t)**2) # 段裏スラブの鉛直方向の厚み（入隅線から測る）
    prof = [[0.0, 0.0]]
    n.times do |k|
      prof << [k * t, (k + 1) * h]
      prof << [(k + 1) * t, (k + 1) * h] if k < n - 1
    end
    s_end = (n - 1) * t
    # 段裏: 入隅を結ぶ線 z = s*h/t から wp 下げた線
    prof << [s_end, (n - 1) * h - wp]
    prof << [wp * t / h, 0.0]
    pts = prof.map do |s, z|
      dir == :x ? pt(base[0] + s, base[1], z0 + z) : pt(base[0], base[1] + s, z0 + z)
    end
    width = dir == :x ? Geom::Vector3d.new(0, STAIR_W.mm, 0) : Geom::Vector3d.new(STAIR_W.mm, 0, 0)
    g = ents.add_group
    prism(g.entities, pts, width, material)
    g
  end

  # 手摺: 折れ線 [[x,y,z_bottom],...] に沿ったガラス板と笠木
  def guard(ents, path, glass_mat, cap_mat)
    g = ents.add_group
    path.each_cons(2) do |a, b|
      dx = b[0] - a[0]
      dy = b[1] - a[1]
      len = Math.hypot(dx, dy)
      next if len < 1.0
      nx = -dy / len
      ny = dx / len
      # ガラス
      off = GLASS_T / 2.0
      q = [[a[0] - nx * off, a[1] - ny * off, a[2]], [b[0] - nx * off, b[1] - ny * off, b[2]],
           [b[0] - nx * off, b[1] - ny * off, b[2] + RAIL_H - CAP_H], [a[0] - nx * off, a[1] - ny * off, a[2] + RAIL_H - CAP_H]]
      prism(g.entities, q.map { |p| pt(*p) }, Geom::Vector3d.new((nx * GLASS_T).mm, (ny * GLASS_T).mm, 0), glass_mat)
      # 笠木
      off = CAP_W / 2.0
      q = [[a[0] - nx * off, a[1] - ny * off, a[2] + RAIL_H - CAP_H], [b[0] - nx * off, b[1] - ny * off, b[2] + RAIL_H - CAP_H],
           [b[0] - nx * off, b[1] - ny * off, b[2] + RAIL_H], [a[0] - nx * off, a[1] - ny * off, a[2] + RAIL_H]]
      prism(g.entities, q.map { |p| pt(*p) }, Geom::Vector3d.new((nx * CAP_W).mm, (ny * CAP_W).mm, 0), cap_mat)
    end
    g
  end

  # ===========================================================================
  # STEP B: 階別タグ
  # ===========================================================================
  def floor_tag_layers
    layers = model.layers
    folder = nil
    if layers.respond_to?(:add_folder)
      folder = layers.folders.find { |f| f.name == TAG_FOLDER } || layers.add_folder(TAG_FOLDER)
    end
    FLOOR_TAGS.each_with_object({}) do |(key, (name, rgb)), h|
      l = layers[name] || layers.add(name)
      l.color = Sketchup::Color.new(*rgb)
      folder.add_layer(l) if folder && l.folder != folder
      h[key] = l
    end
  end

  def band_start(key)
    key == '1F' ? -Float::INFINITY : FL[key] - BAND_OFFSET
  end

  def classify(mn, mx)
    keys = FL.keys
    idx = keys.rindex { |k| mn[2] + 1.0 >= band_start(k) } || 0
    nxt = keys[idx + 1]
    return 'MULTI' if nxt && mx[2] > band_start(nxt) + SPAN_TOL
    keys[idx]
  end

  def reassignable?(layer)
    DEFAULT_TAG_NAMES.include?(layer.name) || FLOOR_TAGS.values.any? { |n, _| n == layer.name }
  end

  def step_b_floor_tags
    model.start_operation('階別タグの振り分け', true)
    tags = floor_tag_layers
    @stat = Hash.new(0)
    bld = model.entities.find { |e| container?(e) && e.name.start_with?(BUILDING_PREFIX) }
    raise "建物グループ「#{BUILDING_PREFIX}…」が見つかりません" unless bld
    unique!(bld)
    walk(bld.definition.entities, bld.transformation, tags, nil)
    model.commit_operation
    msg = FLOOR_TAGS.map { |k, (n, _)| "#{n}: #{@stat[k]}" }.join(' / ')
    puts "[STEP B 完了] 階別タグを設定した要素数  #{msg}"
    msg
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP B でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
  end

  def floor_by_name(name)
    rule = NAME_FLOOR_RULES.find { |re, _| name =~ re }
    rule && rule[1]
  end

  def resolve(cls, forced, mn)
    return cls unless forced && FL.key?(cls)
    keys = FL.keys
    return forced if cls == forced
    return forced if keys.index(cls) == keys.index(forced) + 1 && mn[2] < FL[cls] - 1.0
    cls
  end

  # forced: 親グループ名で階が決まっている場合のその階（なければ nil）
  def walk(ents, tr, tags, forced)
    ents.to_a.each do |e|
      next unless e.respond_to?(:layer)
      if container?(e)
        next if SKIP_PREFIXES.any? { |p| e.name.start_with?(p) }
        mn, mx = world_bb_mm(e, tr)
        next unless mn
        f = floor_by_name(e.name) || forced
        cls = resolve(classify(mn, mx), f, mn)
        has_children = e.definition.entities.any? { |c| container?(c) }
        if e.is_a?(Sketchup::Group) && reassignable?(e.layer) && flat_multi_level?(e, tr)
          # 例: 「テラス ウッドデッキ」= 2F デッキ面と 3F 展望テラス面が同じグループ内
          unique!(e)
          walk(e.definition.entities, tr * e.transformation, tags, f)
        elsif reassignable?(e.layer) && (cls != 'MULTI' || !has_children || e.is_a?(Sketchup::ComponentInstance))
          set_tag(e, cls, tags)
        elsif e.is_a?(Sketchup::Group)
          # 部位別タグ付きのグループ、または複数階にまたがるグループは中へ降りる
          unique!(e)
          walk(e.definition.entities, tr * e.transformation, tags, f)
        end
      elsif e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Text)
        next unless reassignable?(e.layer)
        mn, mx = world_bb_mm(e, tr)
        next unless mn
        set_tag(e, resolve(classify(mn, mx), forced, mn), tags)
      end
    end
  end

  # 子グループを持たず、水平面だけで構成され、その面が複数の階にまたがるグループか
  def flat_multi_level?(grp, tr)
    ents = grp.definition.entities
    return false if ents.any? { |c| container?(c) }
    faces = ents.grep(Sketchup::Face)
    return false if faces.empty? || faces.any? { |fc| fc.normal.z.abs < 0.999 }
    t = tr * grp.transformation
    faces.map { |fc| mn, mx = world_bb_mm(fc, t); classify(mn, mx) }.uniq.size > 1
  end

  def set_tag(e, cls, tags)
    e.layer = tags[cls]
    @stat[cls] += 1
  end

  def run_all
    step_a_south_void
    step_b_floor_tags
    UI.messagebox("修正が完了しました。\n詳細は Ruby コンソールのログを確認してください。\n" \
                  "元に戻す場合は [編集]→[元に戻す] を2回（STEP B→STEP A）。")
  end
end

TomitaFix.run_all if TomitaFix::AUTO_RUN && defined?(Sketchup)
