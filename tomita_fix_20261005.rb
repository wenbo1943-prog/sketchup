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
#  STEP C  その他の室構成を図面に合わせる（間仕切の撤去・追加、扉、室名、床仕上、
#          2F 出会いホールの床・天井、3F 展望テラスの範囲と手摺）
#  STEP D  天井高さ（ふところ850＋スラブ300）、3F 天井の新設、天井ふところの外周を塞ぐ、
#          妻面の壁をガラスから土壁へ（何度でも再実行可。PLENUM を変えれば天井を作り直す）
#  STEP B  階ごとのタグ（レイヤー）を作成し、全要素を 1F/2F/3F/RF/複数階 に振り分け
#          - 既存の「部位別タグ」（01_構造… 等）は親グループ側に残すので、
#            部位別・階別のどちらでも表示/非表示を切り替えられる
#
# 使い方:
#   1. 元の .skp を必ず別名でバックアップしてから開く
#   2. [拡張機能]→[Ruby コンソール] を開き、次を入力して Enter
#        load 'C:/temp/tomita_fix_20261005.rb'
#      ※ このファイルは日本語を含まないフォルダ（例: C:/temp）に置くと確実です
#      （このファイルを読み込むと STEP A → C → D → B の順で自動実行されます。
#        実行済みの STEP A・C は自動でスキップします）
#      個別に実行したい場合は、先頭の AUTO_RUN を false にして読み込み後に
#        TomitaFix.step_a_south_void / step_c_rooms / step_d_ceilings / step_b_floor_tags
#   3. 結果が気に入らなければ [編集]→[元に戻す] を、実行された STEP の数だけ押すと元に戻ります
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

# 同じ SketchUp で読み込み直したときの「already initialized constant」警告を出さないよう、前回の定義を消す
Object.send(:remove_const, :TomitaFix) if defined?(TomitaFix)

module TomitaFix
  VERSION = '2026-10-05 v4（STEP A/C/D/B）'.freeze
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

  def mat_prefix(prefix)
    model.materials.find { |m| m.name.start_with?(prefix) }
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
      puts 'STEP A は実行済みのためスキップしました。'
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
    cap = mat_prefix('05_木格子') # 既存の手摺と同じ（ガラス＋木の笠木）
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
  # STEP C: 室構成・間仕切・建具・床仕上げを 20260918案に合わせる
  #   根拠: モデル内 DWG の線（座標）＋ PDF の線種（実線＝壁、破線＝壁なし）
  # ===========================================================================
  WALL_T = 120.0
  DOOR_T = 150.0
  CEIL = { '1F' => [0.0, 4000.0], '2F' => [5000.0, 8500.0], '3F' => [9500.0, 13700.0] }.freeze
  FIN_Z = { '1F' => 8.0, '2F' => 5008.0, '3F' => 9508.0 }.freeze

  # 撤去する既存要素（グループ名, [world bbox x0,y0,z0,x1,y1,z1 (mm)]）
  #   1F: 控室A/B間の壁と扉、グループブースA/B間のガラス、X=31,850 の壁（段違いに付け替え）、荷物用EV扉（南面）
  #   2F: X=15,950 のガラス（青少年交流スペース西側は図面で破線）、Y=22,350 のガラス（破線）、
  #       Y=32,650 X28,850〜31,350 のガラス（破線）、荷物用EV扉（南面）
  #   3F: 階段室西の X=31,350 の壁（Y37,950 で止める）、階段室扉、スタジオ間の壁に付いていた扉、荷物用EV扉
  #   外部階段グループ: 2F 旧テラスの手摺、3F 展望テラスの範囲外になる手摺
  DELETE_LIST = [
    ['1F 間仕切・建具', [
      [27040, 22350, 0, 27160, 24650, 60],
      [27040, 22350, 3940, 27160, 24650, 4000],
      [27060, 23475, 0, 27140, 23525, 4000],
      [10550, 52090, 0, 15850, 52210, 4000],
      [27090, 22350, 60, 27110, 24650, 3940],
      [31790, 22350, 0, 31910, 34950, 4000],
      [12750, 52075, 0, 13650, 52225, 2200],
      [23300, 44875, 0, 24400, 45025, 2200]
    ]],
    ['2F 間仕切・建具', [
      [15890, 22350, 5000, 16010, 44950, 5060],
      [15890, 22350, 8440, 16010, 44950, 8500],
      [15910, 22325, 5000, 15990, 22375, 8500],
      [15910, 23738, 5000, 15990, 23788, 8500],
      [15910, 25150, 5000, 15990, 25200, 8500],
      [15910, 26563, 5000, 15990, 26613, 8500],
      [15910, 27975, 5000, 15990, 28025, 8500],
      [15910, 29388, 5000, 15990, 29438, 8500],
      [15910, 30800, 5000, 15990, 30850, 8500],
      [15910, 32212, 5000, 15990, 32262, 8500],
      [15910, 33625, 5000, 15990, 33675, 8500],
      [15910, 35038, 5000, 15990, 35088, 8500],
      [15910, 36450, 5000, 15990, 36500, 8500],
      [15910, 37862, 5000, 15990, 37912, 8500],
      [15910, 39275, 5000, 15990, 39325, 8500],
      [15910, 40688, 5000, 15990, 40738, 8500],
      [15910, 42100, 5000, 15990, 42150, 8500],
      [15910, 43512, 5000, 15990, 43562, 8500],
      [15910, 44925, 5000, 15990, 44975, 8500],
      [28850, 32630, 5000, 31350, 32750, 5060],
      [28850, 32630, 8440, 31350, 32750, 8500],
      [28825, 32650, 5000, 28875, 32730, 8500],
      [30075, 32650, 5000, 30125, 32730, 8500],
      [31325, 32650, 5000, 31375, 32730, 8500],
      [7850, 22290, 5000, 15950, 22410, 5060],
      [7850, 22290, 8440, 15950, 22410, 8500],
      [7825, 22310, 5000, 7875, 22390, 8500],
      [9175, 22310, 5000, 9225, 22390, 8500],
      [10525, 22310, 5000, 10575, 22390, 8500],
      [11875, 22310, 5000, 11925, 22390, 8500],
      [13225, 22310, 5000, 13275, 22390, 8500],
      [14575, 22310, 5000, 14625, 22390, 8500],
      [15925, 22310, 5000, 15975, 22390, 8500],
      [15940, 22350, 5060, 15960, 44950, 8440],
      [28850, 32680, 5060, 31350, 32700, 8440],
      [7850, 22340, 5060, 15950, 22360, 8440],
      [23300, 44875, 5000, 24400, 45025, 7200]
    ]],
    ['3F 間仕切・建具', [
      [31290, 25850, 9500, 31410, 40950, 13700],
      [23300, 44875, 9500, 24400, 45025, 11700],
      [31275, 39000, 9500, 31425, 39900, 11700],
      [15875, 17450, 9500, 16025, 19250, 11700],
      [22875, 17450, 9500, 23025, 19250, 11700],
      [29875, 17450, 9500, 30025, 19250, 11700]
    ]],
    ['外部階段 (1F→2F) ・ 歩道橋接続', [
      [37430, -220, 5000, 37470, -180, 6050],
      [37380, -220, 5000, 37420, -180, 6050],
      [37380, 1230, 5000, 37420, 1270, 6050],
      [37380, 2680, 5000, 37420, 2720, 6050],
      [37380, 4130, 5000, 37420, 4170, 6050],
      [37380, 5580, 5000, 37420, 5620, 6050],
      [4780, -220, 5000, 4820, -180, 6050],
      [4780, 1218, 9500, 4820, 1258, 10550],
      [4780, 2655, 9500, 4820, 2695, 10550],
      [4780, 4093, 9500, 4820, 4133, 10550],
      [6316, -230, 9500, 6356, -190, 10550],
      [7901, -230, 9500, 7941, -190, 10550],
      [9487, -230, 9500, 9527, -190, 10550],
      [11073, -230, 9500, 11113, -190, 10550],
      [12659, -230, 9500, 12699, -190, 10550],
      [14244, -230, 9500, 14284, -190, 10550],
      [37392, -200, 5100, 37408, 5600, 6050],
      [37360, -200, 6050, 37440, 5600, 6100],
      [4792, -200, 9600, 4808, 5550, 10550],
      [4760, -200, 10550, 4840, 5550, 10600],
      [4750, -218, 9600, 15850, -202, 10550],
      [4750, -250, 10550, 15850, -170, 10600]
    ]]
  ].freeze

  # 追加する壁 [階, x0, y0, x1, y1, 材料]（壁芯線、厚さ120、床〜天井）
  ADD_WALLS = [
    ['1F', 5_150, 47_450, 5_150, 56_850, '43_'],    # 多目的会議室1/2 間
    ['1F', 28_600, 24_650, 28_600, 32_450, '43_'],  # 控室1/2 間
    ['1F', 31_850, 22_350, 31_850, 32_450, '43_'],  # 倉庫2 西（南側）
    ['1F', 31_350, 32_450, 31_350, 34_950, '43_'],  # 倉庫2 西（北側・段違い）
    ['2F', 15_950, 32_650, 15_950, 44_950, '44_'],  # スタジオ1 西
    ['2F', 15_950, 32_650, 25_350, 32_650, '44_'],  # スタジオ1 南
    ['2F', 15_950, 5_650, 15_950, 20_650, '43_'],   # プレイルーム2 西
    ['2F', 15_950, 20_650, 37_350, 20_650, '43_'],  # プレイルーム2 北
    ['3F', 31_350, 25_850, 31_350, 37_950, '43_'],  # 更衣室×2・設備関連 西（階段室部分を除く）
    ['3F', 28_850, 37_950, 31_350, 37_950, '43_']   # 階段室 南（図面では階段室が X28,850 まで広い）
  ].freeze

  # 追加する扉 [階, x0, y0, x1, y1, 高さ, 材料]
  ADD_DOORS = [
    ['1F', 22_275, 45_650, 22_425, 46_750, 2200, '12_'],  # 荷物用EV（図面の扉位置＝西面）
    ['2F', 22_275, 45_650, 22_425, 46_750, 2200, '12_'],
    ['3F', 22_275, 45_650, 22_425, 46_750, 2200, '12_'],
    ['3F', 18_450, 25_775, 20_450, 25_925, 2200, '45_'],  # スタジオ2 両開き（DWG の扉軌跡）
    ['3F', 25_450, 25_775, 27_450, 25_925, 2200, '45_'],  # スタジオ3 両開き
    ['3F', 30_050, 25_775, 31_250, 25_925, 2200, '45_'],  # スタジオ4
    ['3F', 29_650, 37_875, 30_550, 38_025, 2200, '45_']   # 階段室（既存扉を新しい壁へ移設）
  ].freeze

  # 材料を変更する既存要素（3F 倉庫10＝旧「スタジオ1」の壁: 吸音木パネル → 白壁）
  RECOLOR = [
    ['3F 間仕切・建具', [22_290, 28_450, 9_500, 22_410, 40_950, 13_700], '43_'],
    ['3F 間仕切・建具', [22_350, 40_890, 9_500, 25_390, 41_010, 13_700], '43_'],
    ['3F 間仕切・建具', [22_350, 28_390, 9_500, 28_850, 28_510, 13_700], '43_'],
    ['3F 間仕切・建具', [28_790, 28_450, 9_500, 28_910, 40_950, 13_700], '43_']
  ].freeze

  # 室床仕上: 削除する面（bbox x0,y0,x1,y1）と追加する面（多角形, 材料）
  #   材料はモデル既存の室用途→仕上げの対応に合わせる
  #   （会議室=24 / 控室・管理人室=28 / 倉庫=29 / プレイルーム=31 / 交流=23 / スタジオ=33 / 市民活動拠点=21）
  FINISH_DELETE = {
    '1F' => [[-50, 47_450, 10_550, 56_850], [10_550, 52_150, 15_850, 56_850], [10_550, 47_450, 15_850, 52_150],
             [15_950, -150, 29_950, 22_350], [29_950, 14_350, 37_350, 22_350], [29_950, 6_370, 37_350, 14_350],
             [29_950, -150, 37_350, 6_370], [22_350, 22_350, 27_100, 24_650], [27_100, 22_350, 31_850, 24_650],
             [25_350, 24_650, 31_850, 32_450], [31_850, 22_350, 37_350, 34_950]],
    '2F' => [[7_850, 5_600, 37_350, 22_350], [15_950, 22_350, 37_350, 32_690], [15_950, 32_690, 25_350, 44_950]]
  }.freeze
  FINISH_ADD = [
    ['1F', [[-50, 47_450], [5_150, 47_450], [5_150, 56_850], [-50, 56_850]], '24_'],            # 多目的会議室1
    ['1F', [[5_150, 47_450], [10_550, 47_450], [10_550, 56_850], [5_150, 56_850]], '24_'],      # 多目的会議室2
    ['1F', [[10_550, 47_450], [15_850, 47_450], [15_850, 56_850], [10_550, 56_850]], '24_'],    # 多目的会議室3
    ['1F', [[15_950, -150], [37_350, -150], [37_350, 22_350], [15_950, 22_350]], '31_'],        # プレイルーム1
    ['1F', [[22_350, 22_350], [31_850, 22_350], [31_850, 24_650], [22_350, 24_650]], '29_'],    # 倉庫3
    ['1F', [[25_350, 24_650], [28_600, 24_650], [28_600, 32_450], [25_350, 32_450]], '28_'],    # 控室1
    ['1F', [[28_600, 24_650], [31_850, 24_650], [31_850, 32_450], [28_600, 32_450]], '28_'],    # 控室2
    ['1F', [[31_850, 22_350], [37_350, 22_350], [37_350, 34_950], [31_350, 34_950],
            [31_350, 32_450], [31_850, 32_450]], '29_'],                                        # 倉庫2（L字）
    ['2F', [[15_950, 5_650], [37_350, 5_650], [37_350, 20_650], [15_950, 20_650]], '31_'],      # プレイルーム2
    ['2F', [[15_950, 20_650], [37_350, 20_650], [37_350, 32_650], [15_950, 32_650]], '23_'],    # 青少年交流スペース
    ['2F', [[15_950, 32_650], [25_350, 32_650], [25_350, 44_950], [15_950, 44_950]], '33_'],    # スタジオ1
    ['2F', [[11_950, 9_650], [15_950, 9_650], [15_950, 13_650], [11_950, 13_650]], '24_'],      # グループブース1
    ['2F', [[11_950, 5_650], [15_950, 5_650], [15_950, 9_650], [11_950, 9_650]], '24_']         # グループブース2
  ].freeze
  FINISH_RECOLOR = [
    ['3F', [22_350, 28_450, 28_850, 40_950], '29_'],  # 倉庫10
    ['3F', [15_950, 31_450, 22_350, 40_150], '21_']   # 市民活動拠点
  ].freeze

  LABEL_DELETE = ['1F まちかどテラス', '1F 控室A', '1F 控室B', '1F グループブースA', '1F グループブースB',
                  '1F 市民活動拠点', '1F 交流テラスホール', '2F プレイルーム(800㎡)', '2F 交流ホール'].freeze
  LABEL_RENAME = { '3F スタジオ1' => '3F 倉庫10', '3F 倉庫' => '3F 市民活動拠点' }.freeze
  LABEL_ADD = [
    ['1F 多目的会議室1', 2_500, 52_150, 1_500], ['1F 多目的会議室2', 7_850, 52_150, 1_500],
    ['1F 多目的会議室3', 13_200, 52_150, 1_500], ['1F 倉庫3', 27_100, 23_500, 1_500],
    ['1F 控室1', 26_975, 28_550, 1_500], ['1F 控室2', 30_225, 28_550, 1_500],
    ['1F みまもりテラスホール', 9_500, 5_000, 1_500],
    ['2F プレイルーム2', 26_650, 13_150, 6_500], ['2F 青少年交流スペース(小中高生)', 26_650, 26_650, 6_500],
    ['2F 青少年交流ホール', 11_700, 17_800, 6_500], ['2F スタジオ1(小中高生)', 20_650, 38_800, 6_500],
    ['2F グループブース1', 13_950, 11_650, 6_500], ['2F グループブース2', 13_950, 7_650, 6_500]
  ].freeze

  def bb_match?(ent, tr, want, tol = 3.0)
    mn, mx = world_bb_mm(ent, tr)
    return false unless mn
    (mn + mx).zip(want).all? { |a, b| (a - b).abs <= tol }
  end

  def wall_box(ents, x0, y0, x1, y1, z0, z1, material)
    h = WALL_T / 2.0
    if (y1 - y0).abs < 1.0 # X方向の壁
      box(ents, [x0, x1].min, y0 - h, z0, [x0, x1].max, y0 + h, z1, material)
    else                   # Y方向の壁
      box(ents, x0 - h, [y0, y1].min, z0, x0 + h, [y0, y1].max, z1, material)
    end
  end

  def step_c_rooms
    if model.get_attribute(MARK_DICT, 'rooms_done')
      puts 'STEP C は実行済みのためスキップしました。'
      return
    end
    model.start_operation('室構成・間仕切を図面に合わせる', true)
    log = []

    # --- C1. 既存要素の撤去 ---
    DELETE_LIST.each do |gname, boxes|
      g, gtr = find_one(gname)
      unique!(g)
      ents = g.definition.entities
      dead = []
      missing = 0
      boxes.each do |want|
        hit = ents.find { |e| container?(e) && !dead.include?(e) && bb_match?(e, gtr, want) }
        hit ? dead << hit : missing += 1
      end
      ents.erase_entities(dead) unless dead.empty?
      log << "「#{gname}」から #{dead.size}要素を撤去" + (missing > 0 ? "（#{missing}件は見つからず）" : '')
    end

    # --- C2. 壁・扉の追加、材料変更 ---
    ADD_WALLS.each do |fl, x0, y0, x1, y1, mp|
      g, gtr = find_one("#{fl} 間仕切・建具")
      w = g.definition.entities.add_group
      w.name = "追加壁(20260918案)"
      w.transformation = gtr.inverse
      z0, z1 = CEIL[fl]
      wall_box(w.entities, x0, y0, x1, y1, z0, z1, mat_prefix(mp))
    end
    log << "壁を #{ADD_WALLS.size}か所追加"
    ADD_DOORS.each do |fl, x0, y0, x1, y1, hgt, mp|
      g, gtr = find_one("#{fl} 間仕切・建具")
      d = g.definition.entities.add_group
      d.name = mp == '12_' ? '荷物用EV扉' : '扉'
      d.transformation = gtr.inverse
      z0 = CEIL[fl][0]
      box(d.entities, x0, y0, z0, x1, y1, z0 + hgt, mat_prefix(mp))
    end
    log << "扉を #{ADD_DOORS.size}か所追加（荷物用EV 3・スタジオ 3・3F階段室 1）"
    RECOLOR.each do |gname, want, mp|
      g, gtr = find_one(gname)
      hit = g.definition.entities.find { |e| container?(e) && bb_match?(e, gtr, want) }
      hit.material = mat_prefix(mp) if hit
    end
    log << '3F 倉庫10 の壁を白壁に変更'

    # --- C3. 室床仕上 ---
    %w[1F 2F 3F].each do |fl|
      hits = find_named("#{fl} 室床仕上")
      next if hits.empty?
      g, gtr = hits.first
      unique!(g)
      ents = g.definition.entities
      inv = gtr.inverse
      z = pt(0, 0, FIN_Z[fl]).transform(inv).z.to_mm
      (FINISH_DELETE[fl] || []).each do |x0, y0, x1, y1|
        r = rect_to_local({ x0: x0, y0: y0, x1: x1, y1: y1 }, gtr)
        dead = ents.grep(Sketchup::Face).select do |f|
          b = f.bounds
          horizontal_at?(f, z) && (b.min.x.to_mm - r[:x0]).abs < 5 && (b.min.y.to_mm - r[:y0]).abs < 5 &&
            (b.max.x.to_mm - r[:x1]).abs < 5 && (b.max.y.to_mm - r[:y1]).abs < 5
        end
        ents.erase_entities(dead) unless dead.empty?
        erase_faces_inside(ents, r, z) # 残った辺の整理
      end
      FINISH_ADD.select { |f, _, _| f == fl }.each do |_, poly, mp|
        f = ents.add_face(poly.map { |x, y| pt(x, y, FIN_Z[fl]).transform(inv) })
        next unless f
        f.reverse! if f.normal.z < 0
        f.material = mat_prefix(mp)
      end
      FINISH_RECOLOR.select { |f, _, _| f == fl }.each do |_, (x0, y0, x1, y1), mp|
        r = rect_to_local({ x0: x0, y0: y0, x1: x1, y1: y1 }, gtr)
        ents.grep(Sketchup::Face).each do |f|
          b = f.bounds
          next unless horizontal_at?(f, z) && (b.min.x.to_mm - r[:x0]).abs < 5 && (b.min.y.to_mm - r[:y0]).abs < 5 &&
                      (b.max.x.to_mm - r[:x1]).abs < 5 && (b.max.y.to_mm - r[:y1]).abs < 5
          f.material = mat_prefix(mp)
        end
      end
    end
    log << '室床仕上を新しい室割りに合わせて更新'

    # --- C4. 2F 出会いホール・3F 展望テラス ---
    deck = find_named('テラス ウッドデッキ').first
    if deck
      g, gtr = deck
      unique!(g)
      ents = g.definition.entities
      z2 = pt(0, 0, 5008).transform(gtr.inverse).z.to_mm
      dead = ents.grep(Sketchup::Face).select { |f| horizontal_at?(f, z2) }
      ents.erase_entities(dead) unless dead.empty?
      stray = ents.grep(Sketchup::Edge).select { |e| e.faces.empty? }
      ents.erase_entities(stray) unless stray.empty?
      # 3F: Y5,550 より南は X15,850 から東だけが展望テラス（DWG）
      z3 = pt(0, 0, 9508).transform(gtr.inverse).z.to_mm
      r = rect_to_local({ x0: 4_750, y0: -250, x1: 15_850, y1: 5_550 }, gtr)
      ents.grep(Sketchup::Face).select { |f| horizontal_at?(f, z3) }.each do |f|
        c = clip_rect(r, f.bounds)
        next unless c
        ents.add_face(rect_pts(c, z3))
        erase_faces_inside(ents, c, z3)
      end
      log << '2F 出会いホールのデッキ面を撤去（床はナラ）、3F 展望テラスのデッキを図面範囲に縮小'
    end
    ceil = find_named('2F 天井').first
    if ceil
      g, gtr = ceil
      unique!(g)
      f = g.definition.entities.add_face(rect_pts(rect_to_local({ x0: 4_950, y0: -150, x1: 37_350, y1: 5_600 }, gtr),
                                                  pt(0, 0, 8500).transform(gtr.inverse).z.to_mm))
      if f
        f.reverse! if f.normal.z > 0 # 天井は下向き
        f.material = mat_prefix('41_')
      end
      log << '2F 天井を出会いホール・南側吹抜けの上まで延長'
    end
    host, htr = find_one('外部階段 (1F→2F) ・ 歩道橋接続')
    rg = host.definition.entities.add_group
    rg.name = '3F 展望テラス 手摺（範囲変更分）'
    rg.transformation = htr.inverse
    gl = mat('11_手摺ガラス')
    cap = mat_prefix('05_木格子')
    guard(rg.entities, [[4_800, 5_550, 9_500], [15_850, 5_550, 9_500]], gl, cap)
    guard(rg.entities, [[15_850, -200, 9_500], [15_850, 5_550, 9_500]], gl, cap)
    log << '3F 展望テラスの新しい縁（Y5,550 / X15,850）に手摺を追加'

    # --- C5. 室名 ---
    texts = find_texts
    n_del = 0
    texts.each do |tx, _|
      if LABEL_DELETE.include?(tx.text)
        tx.erase!
        n_del += 1
      elsif LABEL_RENAME.key?(tx.text)
        log << "室名「#{tx.text}」→「#{LABEL_RENAME[tx.text]}」"
        tx.text = LABEL_RENAME[tx.text]
      end
    end
    lg, ltr = find_one('室名')
    unique!(lg)
    LABEL_ADD.each { |t, x, y, z| lg.definition.entities.add_text(t, pt(x, y, z).transform(ltr.inverse)) }
    log << "室名を #{n_del}件削除・#{LABEL_ADD.size}件追加"

    model.set_attribute(MARK_DICT, 'rooms_done', true)
    model.commit_operation
    puts "[STEP C 完了]\n  " + log.join("\n  ")
    log
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP C でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
  end

  # ===========================================================================
  # STEP D: 天井（1F・2F の高さ変更、3F 新設）、天井ふところの塞ぎ、妻面の材料
  #   天井高さ = 上階 FL − スラブ 300 − 天井ふところ PLENUM
  #   PLENUM を 800〜900 の範囲で変えて再実行すると、天井と塞ぎを作り直す（何度でも実行可）
  # ===========================================================================
  PLENUM = 850.0
  SLAB_T = 300.0
  UPPER_FL = { '1F' => 5000.0, '2F' => 9500.0, '3F' => 14000.0 }.freeze # 3F は大屋根の桁上端
  # 天井の範囲（外壁の内面、mm）。吹抜け（西側 1F〜大屋根、南側 1F〜2F）と階段は切り欠き
  CEIL_POLY = {
    '1F' => [[4_950, -50], [15_950, -50], [15_950, 5_650], [37_250, 5_650], [37_250, 37_950], [31_350, 37_950],
             [31_350, 40_850], [25_250, 40_850], [25_250, 56_750], [-50, 56_750], [-50, 44_950], [13_450, 44_950],
             [13_450, 27_150], [4_950, 27_150], [4_950, 16_850], [7_850, 16_850], [7_850, 10_850], [4_950, 10_850]],
    '2F' => [[4_950, -50], [37_250, -50], [37_250, 37_950], [31_350, 37_950],
             [31_350, 40_850], [25_250, 40_850], [25_250, 56_750], [-50, 56_750], [-50, 44_950], [13_450, 44_950],
             [13_450, 27_150], [4_950, 27_150], [4_950, 16_850], [7_850, 16_850], [7_850, 10_850], [4_950, 10_850]],
    '3F' => [[4_950, 10_950], [37_250, 10_950], [37_250, 40_850], [25_250, 40_850], [25_250, 56_750], [-50, 56_750],
             [-50, 44_950], [13_450, 44_950], [13_450, 27_150], [4_950, 27_150]]
  }.freeze
  SEAL_T = 20.0
  GABLE_GROUP = '妻面 ガラス・土壁'.freeze

  def ceil_z(fl)
    UPPER_FL[fl] - SLAB_T - PLENUM
  end

  def step_d_ceilings
    model.start_operation('天井の高さ・3F天井・天井ふところ塞ぎ・妻面材料', true)
    log = []
    host, htr = find_one('内装 床仕上・天井')
    unique!(host)
    hents = host.definition.entities
    ceil_mat = mat_prefix('41_')
    %w[1F 2F 3F].each do |fl|
      z = ceil_z(fl)
      # --- 天井面（既存の 1F/2F 天井は作り直し、3F は新設） ---
      g = hents.find { |e| e.is_a?(Sketchup::Group) && e.name == "#{fl} 天井" }
      if g
        unique!(g)
        g.definition.entities.clear!
      else
        g = hents.add_group
        g.name = "#{fl} 天井"
      end
      g.transformation = htr.inverse
      f = g.entities.add_face(CEIL_POLY[fl].map { |x, y| pt(x, y, z) })
      if f
        f.reverse! if f.normal.z > 0 # 下から見える向き
        f.material = ceil_mat
        f.back_material = ceil_mat
      end
      # --- 天井ふところの塞ぎ（天井の外周すべて: 外壁側・吹抜け側・階段側） ---
      old = hents.select { |e| e.is_a?(Sketchup::Group) && e.name == "天井ふところ塞ぎ #{fl}" }
      hents.erase_entities(old) unless old.empty?
      sg = hents.add_group
      sg.name = "天井ふところ塞ぎ #{fl}"
      sg.transformation = htr.inverse
      poly = CEIL_POLY[fl]
      area2 = poly.each_with_index.sum { |(x0, y0), i| x1, y1 = poly[(i + 1) % poly.size]; x0 * y1 - x1 * y0 }
      poly = poly.reverse if area2 < 0 # 反時計回りにそろえる（内側＝左手）
      ztop = fl == '3F' ? 13_700.0 : UPPER_FL[fl] - SLAB_T # スラブ下端（3F は外壁ガラス上端）
      poly.each_with_index do |(x0, y0), i|
        x1, y1 = poly[(i + 1) % poly.size]
        len = Math.hypot(x1 - x0, y1 - y0)
        next if len < 1.0
        nx = -(y1 - y0) / len * SEAL_T
        ny = (x1 - x0) / len * SEAL_T
        q = [pt(x0, y0, z), pt(x1, y1, z), pt(x1 + nx, y1 + ny, z), pt(x0 + nx, y0 + ny, z)]
        prism(sg.entities, q, Geom::Vector3d.new(0, 0, (ztop - z).mm), ceil_mat)
      end
      log << "#{fl} 天井 FL+#{(z - (fl == '1F' ? 0 : fl == '2F' ? 5000 : 9500)).round}（z=#{z.round}）、ふところ塞ぎ z#{z.round}〜#{ztop.round}"
    end

    # --- 妻面の壁: ガラス → 土壁 ---
    hits = find_named(GABLE_GROUP)
    if hits.empty?
      log << "（スキップ）「#{GABLE_GROUP}」なし"
    else
      g, = hits.first
      unique!(g)
      earth = mat_prefix('03_外壁_生成り土壁')
      n = 0
      g.definition.entities.grep(Sketchup::Face).each do |f|
        f.material = earth
        f.back_material = earth
        n += 1
      end
      log << "妻面の壁 #{n}面を土壁に変更"
    end

    model.commit_operation
    puts "[STEP D 完了] 天井ふところ #{PLENUM.round}mm + スラブ #{SLAB_T.round}mm\n  " + log.join("\n  ")
    log
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP D でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
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
    step_c_rooms
    step_d_ceilings
    step_b_floor_tags
    UI.messagebox("修正が完了しました。\n詳細は Ruby コンソールのログを確認してください。\n" \
                  "元に戻す場合は [編集]→[元に戻す] を、実行された STEP の数だけ押してください。")
  end
end

puts "TomitaFix #{TomitaFix::VERSION} を読み込みました" if defined?(Sketchup)
TomitaFix.run_all if TomitaFix::AUTO_RUN && defined?(Sketchup)
