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
#  STEP D  天井高さ（ふところ850＋スラブ300）、天井デザイン（木の板＋黒い天井面）、天井ふところの外周を塞ぐ、
#          妻面の壁をガラスから土壁へ（何度でも再実行可。PLENUM を変えれば天井を作り直す）
#  STEP E  鉄骨化（柱・梁・サッシの材料、梁・垂木を H形鋼形状に）、軒（薄い金属屋根・鉄骨垂木）、
#          吹抜けの手摺（エキスパンドメタル調）、家具の配置（田園調布せせらぎ館を参考）
#  STEP F  軒と屋根（大屋根は薄い屋根板＋細い垂木＋面戸、下屋は小さな持ち出し材とシャンパングレーの鉄骨）
#  STEP G  屋根まわりの鉄骨（妻側の登り梁を木製に、南北の軒の桁・登り梁を柱の内面より奥へ）
#  STEP H  上司の意見（大屋根の軒天を明るく、1階の軒の柱を木の丸柱に、ブリッジ・歩道橋の床と手摺、EXP.J、下屋の梁と垂木の納まり）
#  STEP I  サイン（西の妻面に Takatsuki Common Ground と高槻市章）、妻面のガラス部の木格子
#  STEP J  外構を 261006 の CAD どおりに作り直す（1回だけ）
#  STEP B  階ごとのタグ（レイヤー）を作成し、全要素を 1F/2F/3F/RF/複数階 に振り分け
#          - 既存の「部位別タグ」（01_構造… 等）は親グループ側に残すので、
#            部位別・階別のどちらでも表示/非表示を切り替えられる
#
# 使い方:
#   1. 元の .skp を必ず別名でバックアップしてから開く
#   2. [拡張機能]→[Ruby コンソール] を開き、次の1行を貼り付けて Enter（ダウンロードフォルダの最新のファイルを読み込む）
#        f = Dir.glob('C:/Users/zhang/Downloads/tomita_fix*').max_by { |x| File.mtime(x) }; puts f; load f
#      （このファイルを読み込むと STEP A → C → D → E → F → G → H → I → J → B の順で自動実行されます。
#        実行済みの STEP A・C は自動でスキップします）
#      個別に実行したい場合は、先頭の AUTO_RUN を false にして読み込み後に
#        TomitaFix.step_a_south_void / step_c_rooms / step_d_ceilings / step_e_steel / step_f_roof /
#        step_g_roof_steel / step_h_review / step_i_sign / step_j_exterior / step_b_floor_tags
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
  VERSION = '2026-10-08 v11（STEP A/C/D/E/F/G/H/I/J/B）'.freeze
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
    # 3F は西側吹抜けの上も天井でふさぐ（屋根裏が見えないように）
    '3F' => [[4_950, 10_950], [37_250, 10_950], [37_250, 40_850], [25_250, 40_850], [25_250, 56_750], [-50, 56_750],
             [-50, 30_250], [4_950, 30_250]]
  }.freeze
  SEAL_T = 20.0
  GABLE_GROUP = '妻面 ガラス・土壁'.freeze
  # 天井デザイン（せせらぎ館の内装写真を参考）:
  #   天井高さ（上の式）に木の板（オーク色 300×40 @600）を吊り、
  #   その 150 上に黒っぽい面（スケルトン天井の見え掛かり）を張る
  BOARD_W = 300.0
  BOARD_T = 40.0
  BOARD_PITCH = 600.0
  DARK_OFFSET = 150.0
  NEW_MATS = {
    dark:   ['TF_天井_スケルトン_チャコール #2E3033', [46, 48, 51]],
    board:  ['TF_天井ルーバー_オーク #C9A67C', [201, 166, 124]],
    mesh:   ['TF_手摺_エキスパンドメタル #8C9093', [140, 144, 147], 0.45],
    t_top:  ['TF_家具_天板_白 #F2F1EE', [242, 241, 238]],
    t_leg:  ['TF_家具_脚_黒 #232323', [35, 35, 35]],
    chair:  ['TF_家具_椅子_ブナ #D9C3A0', [217, 195, 160]],
    bench:  ['TF_家具_ベンチ_ファブリック #CFC6B4', [207, 198, 180]]
  }.freeze

  def ceil_z(fl)
    UPPER_FL[fl] - SLAB_T - PLENUM
  end

  def new_mat(key)
    name, rgb, alpha = NEW_MATS[key]
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m.alpha = alpha if alpha
    m
  end

  # 1000mm 立方体の部品（拡大縮小して板・部材に使う）
  def unit_box_def
    d = model.definitions['TF_単位箱_1000']
    return d if d
    d = model.definitions.add('TF_単位箱_1000')
    box(d.entities, 0, 0, 0, 1000, 1000, 1000, nil)
    d
  end

  def place_box(ents, defn, x0, y0, z0, x1, y1, z1, material)
    t = Geom::Transformation.translation(Geom::Vector3d.new(x0.mm, y0.mm, z0.mm)) *
        Geom::Transformation.scaling((x1 - x0) / 1000.0, (y1 - y0) / 1000.0, (z1 - z0) / 1000.0)
    i = ents.add_instance(defn, t)
    i.material = material
    i
  end

  # 直交多角形 poly を水平線 y で切ったときの x 区間
  def x_intervals(poly, y)
    xs = []
    poly.each_with_index do |(x0, y0), i|
      x1, y1 = poly[(i + 1) % poly.size]
      next unless x0 == x1
      lo, hi = [y0, y1].minmax
      xs << x0 if y > lo && y < hi
    end
    xs.sort.each_slice(2).map { |a, b| [a, b] }.select { |a, b| b }
  end

  def intersect_intervals(a, b)
    out = []
    a.each do |a0, a1|
      b.each do |b0, b1|
        lo = [a0, b0].max
        hi = [a1, b1].min
        out << [lo, hi] if hi - lo > 1
      end
    end
    out
  end

  # 天井の板（y 方向 BOARD_PITCH ごと、x 方向に連続）を天井範囲の内側だけに並べる
  def board_strips(poly)
    ys = poly.map { |_, y| y }
    out = []
    yc = ys.min + BOARD_PITCH / 2.0
    while yc + BOARD_W / 2.0 < ys.max
      y0 = yc - BOARD_W / 2.0
      y1 = yc + BOARD_W / 2.0
      probes = [y0 + 1, y1 - 1] + ys.select { |y| y > y0 && y < y1 }.flat_map { |y| [y - 1, y + 1] }
      iv = probes.map { |y| x_intervals(poly, y) }.reduce { |acc, v| intersect_intervals(acc, v) }
      iv.each { |x0, x1| out << [x0, y0, x1, y1] if x1 - x0 >= 600 }
      yc += BOARD_PITCH
    end
    out
  end

  CEIL_HOST_NAME = '内装 床仕上・天井'.freeze

  # 天井グループを入れる場所（entities と、その座標系の world 変換）を探す
  #   1) グループ「内装 床仕上・天井」
  #   2) それが無い場合（分解・名前変更など）は、既存の「1F 天井」等が入っている場所
  #   3) どれも無い場合は、モデル直下に「内装 床仕上・天井」を新しく作る
  def ceiling_host(log)
    host, htr = find_named(CEIL_HOST_NAME).first
    if host
      unique!(host)
      return [host.definition.entities, htr]
    end
    names = %w[1F 2F 3F].flat_map { |fl| ["#{fl} 天井", "天井ルーバー #{fl}", "天井ふところ塞ぎ #{fl}"] }
    names.each do |nm|
      e, t = find_named(nm).first
      next unless e
      log << "（注意）グループ「#{CEIL_HOST_NAME}」が無いため、「#{nm}」と同じ場所に天井を作ります"
      par = e.parent # ComponentDefinition または Model
      return [par.respond_to?(:entities) ? par.entities : par, t * e.transformation.inverse]
    end
    g = model.entities.add_group
    g.name = CEIL_HOST_NAME
    log << "（注意）グループ「#{CEIL_HOST_NAME}」が無いため、モデル直下に新しく作りました"
    [g.entities, Geom::Transformation.new]
  end

  def step_d_ceilings
    model.start_operation('天井の高さ・3F天井・天井ふところ塞ぎ・妻面材料', true)
    log = []
    hents, htr = ceiling_host(log)
    dark = new_mat(:dark)
    oak = new_mat(:board)
    ubox = unit_box_def
    %w[1F 2F 3F].each do |fl|
      z = ceil_z(fl)
      zd = z + DARK_OFFSET
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
      f = g.entities.add_face(CEIL_POLY[fl].map { |x, y| pt(x, y, zd) })
      if f
        f.reverse! if f.normal.z > 0 # 下から見える向き
        f.material = dark
        f.back_material = dark
      end
      # --- 木の板（天井ルーバー） ---
      old = hents.select { |e| e.is_a?(Sketchup::Group) && e.name == "天井ルーバー #{fl}" }
      hents.erase_entities(old) unless old.empty?
      bg = hents.add_group
      bg.name = "天井ルーバー #{fl}"
      bg.transformation = htr.inverse
      strips = board_strips(CEIL_POLY[fl])
      strips.each { |x0, y0, x1, y1| place_box(bg.entities, ubox, x0, y0, z, x1, y1, z + BOARD_T, oak) }
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
        prism(sg.entities, q, Geom::Vector3d.new(0, 0, (ztop - z).mm), dark)
      end
      log << "#{fl} 天井 FL+#{(z - (fl == '1F' ? 0 : fl == '2F' ? 5000 : 9500)).round}（z=#{z.round}）: " \
             "木の板 #{strips.size}本＋黒い天井面 z=#{zd.round}、ふところ塞ぎ z#{z.round}〜#{ztop.round}"
    end

    # --- 妻面の壁: ガラス → 土壁 ---
    hits = find_named(GABLE_GROUP)
    if hits.empty?
      log << "（スキップ）「#{GABLE_GROUP}」なし"
    else
      g, = hits.first
      earth = mat_prefix('03_外壁_生成り土壁')
      faces = g.definition.entities.grep(Sketchup::Face)
      # 一度土壁にしたモデル（土壁の面がある）では、後から手で変えた面（ガラス等）を戻さないよう何もしない
      if model.get_attribute(MARK_DICT, 'gable_earth_done') || faces.any? { |f| f.material == earth }
        model.set_attribute(MARK_DICT, 'gable_earth_done', true)
        log << '妻面の壁は土壁に変更済みのためそのまま（手で変えた面は変更しない）'
      else
        unique!(g)
        faces.each do |f|
          f.material = earth
          f.back_material = earth
        end
        model.set_attribute(MARK_DICT, 'gable_earth_done', true)
        log << "妻面の壁 #{faces.size}面を土壁に変更"
      end
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
  # STEP E: 鉄骨化（柱・梁・サッシ）、軒、手摺、家具（田園調布せせらぎ館を参考）
  #   ・既存の材料「06 扉・柱」「07 窓枠・方立」「02 軒天」「15 下屋 瓦」の色を変える
  #     （同じ材料を使う要素がすべて一度に変わる）
  #   ・梁・垂木（6面の箱）を H形鋼の形状に作り直す（せいは元のまま）
  #   ・下屋は瓦をやめて薄い金属屋根（厚さ100）にし、軒瓦・熨斗瓦を撤去、垂木を約1m間隔に追加
  #   ・大屋根の南側の軒（テラス上）に細い鉄骨垂木を約1m間隔で追加
  #   ・吹抜けの手摺をエキスパンドメタル調に
  #   ・家具（テーブル・椅子・ベンチ）を配置
  # ===========================================================================
  MAT_RECOLOR = [
    ['06_', '06_鉄骨_柱梁_グレー #6E7174', [110, 113, 116]],
    ['07_', '07_サッシ_鉄骨_ダークグレー #3C3F42', [60, 63, 66]],
    ['02_', '02_軒天_スチール_ライトグレー #C4C6C8', [196, 198, 200]],
    ['15_', '15_屋根_ガルバリウム立平_ダークグレー #4F5254', [79, 82, 84]],
    # 各階スラブ位置の木の帯は外から梁のように見えるため、鋼板のスパンドレル（ダークグレー）にする
    ['09_', '09_外壁_スパンドレル_鋼板ダークグレー #3F4245', [63, 66, 69]]
  ].freeze
  MEMBER_GROUPS = ['大屋根 桁・梁', '吹抜け 梁', '大屋根 棟木・登り梁', '下屋 繋ぎ梁・垂木'].freeze
  EAVE_ROOF_T = 100.0
  BIG_RAFTER_X = [-775, 0, 5000, 8100, 12150, 16200, 20700, 25200, 31500, 37200, 37975].freeze
  TABLES = [
    ['2F', 18000, 22100],
    ['2F', 21000, 22100],
    ['2F', 24000, 22100],
    ['2F', 27000, 22100],
    ['2F', 30000, 22100],
    ['2F', 33000, 22100],
    ['2F', 35800, 22100],
    ['2F', 18000, 28100],
    ['2F', 21000, 28100],
    ['2F', 24000, 28100],
    ['2F', 27000, 28100],
    ['2F', 30000, 28100],
    ['2F', 33000, 28100],
    ['2F', 35800, 28100],
    ['2F', 18000, 30400],
    ['2F', 21000, 30400],
    ['2F', 24000, 30400],
    ['2F', 27000, 30400],
    ['2F', 30000, 30400],
    ['2F', 33000, 30400],
    ['2F', 35800, 30400],
    ['1F', 7000, 3000],
    ['1F', 10000, 3000],
    ['1F', 13000, 3000],
    ['1F', 7000, 6000],
    ['1F', 10000, 6000],
    ['1F', 13000, 6000],
    ['1F', 7000, 8800],
    ['1F', 10000, 8800],
    ['1F', 13000, 8800],
    ['3F', 10500, 12700],
    ['3F', 13500, 12700],
    ['3F', 10500, 19600],
    ['3F', 13500, 19600],
    ['3F', 10500, 24200],
    ['3F', 13500, 24200],
    ['2F', 9800, 3200],
    ['2F', 12800, 3200],
    ['2F', 11000, 15500],
    ['2F', 14000, 15500],
    ['2F', 11000, 18500],
    ['2F', 14000, 18500]
  ].freeze
  BENCHES = [
    ['1F', 6800, 800],
    ['1F', 10000, 800],
    ['1F', 13200, 800],
    ['2F', 10000, 700],
    ['2F', 12600, 700],
    ['2F', 14700, 700]
  ].freeze

  # H形鋼の断面（フランジ幅 B・板厚）をせい D から決める
  def h_dims(width, depth)
    b = [[depth / 2.0, 75.0].max, 200.0].min
    b = [b, width].min
    tf = [[b * 0.09, 7.0].max, 19.0].min
    tw = [[b * 0.06, 5.0].max, 12.0].min
    [b, tf, tw]
  end

  # 原点 o、幅方向 wv、せい方向 dv（どちらも長さ付きベクトル, mm）の断面を lv 方向に押し出す
  def h_member(ents, o, wv, dv, lv, material)
    wlen = wv.length.to_mm
    dlen = dv.length.to_mm
    b, tf, tw = h_dims(wlen, dlen)
    wu = wv.clone; wu.normalize!
    du = dv.clone; du.normalize!
    w0 = (wlen - b) / 2.0
    w1 = w0 + b
    wc = wlen / 2.0
    prof = [[w0, 0], [w1, 0], [w1, tf], [wc + tw / 2, tf], [wc + tw / 2, dlen - tf], [w1, dlen - tf], [w1, dlen],
            [w0, dlen], [w0, dlen - tf], [wc - tw / 2, dlen - tf], [wc - tw / 2, tf], [w0, tf]]
    pts = prof.map do |w, d|
      Geom::Point3d.new(o.x + wu.x * w.mm + du.x * d.mm, o.y + wu.y * w.mm + du.y * d.mm, o.z + wu.z * w.mm + du.z * d.mm)
    end
    prism(ents, pts, lv, material)
  end

  # 6面の箱グループから [原点, 幅ベクトル, せいベクトル, 長さベクトル] を取り出す（グループのローカル座標）
  def member_frame(grp)
    ents = grp.definition.entities
    faces = ents.grep(Sketchup::Face)
    return nil unless faces.size == 6 && ents.none? { |e| container?(e) }
    v = faces.first.vertices.first
    vecs = v.edges.map { |e| v.position.vector_to(e.other_vertex(v).position) }
    return nil unless vecs.size == 3
    lv = vecs.max_by(&:length)
    rest = vecs - [lv]
    dv = rest.max_by { |x| x.z.abs / x.length }
    wv = (rest - [dv]).first
    return nil unless wv
    [v.position, wv, dv, lv]
  end

  def members_in(ents, out = [])
    ents.each do |e|
      next unless e.is_a?(Sketchup::Group)
      fr = member_frame(e)
      if fr
        out << [e, ents, fr]
      else
        members_in(e.definition.entities, out)
      end
    end
    out
  end

  def recolor_tree(ent, map)
    if container?(ent)
      ent.material = map[ent.material] if ent.material && map.key?(ent.material)
      ent.definition.entities.each { |c| recolor_tree(c, map) }
    elsif ent.is_a?(Sketchup::Face)
      ent.material = map[ent.material] if ent.material && map.key?(ent.material)
      ent.back_material = map[ent.back_material] if ent.back_material && map.key?(ent.back_material)
    end
  end

  def step_e_steel
    model.start_operation('鉄骨化・軒・手摺・家具（せせらぎ館風）', true)
    log = []
    steel = mat_prefix('06_')
    raise '材料「06_」が見つかりません' unless steel

    unless model.get_attribute(MARK_DICT, 'steel_done')
      # --- E1. 梁・垂木を H形鋼に ---
      eave_params = []
      n = 0
      MEMBER_GROUPS.each do |gname|
        find_named(gname).each do |g, _|
          unique!(g)
          members_in(g.definition.entities).each do |m, parent_ents, (o, wv, dv, lv)|
            unique!(m)
            m.definition.entities.clear!
            h_member(m.definition.entities, o, wv, dv, lv, steel)
            n += 1
            if gname == '下屋 繋ぎ梁・垂木' && lv.z.abs > 1e-6
              t = m.transformation
              eave_params << [parent_ents, o.transform(t), wv.transform(t), dv.transform(t), lv.transform(t)]
            end
          end
        end
      end
      # 1F 下屋グループ直下の繋ぎ梁（材料 06）
      shita, = find_one('1F 下屋 (南・西・北3m / 東0.6m)')
      shita.definition.entities.grep(Sketchup::Group).each do |m|
        next unless m.material == steel || m.definition.entities.grep(Sketchup::Face).first&.material == steel
        fr = member_frame(m)
        next unless fr
        unique!(m)
        m.definition.entities.clear!
        h_member(m.definition.entities, *fr, steel)
        n += 1
      end
      log << "梁・垂木 #{n}本を H形鋼の形状に変更"

      # --- E2. 下屋の垂木を約1m間隔に（既存の垂木の間に追加） ---
      added = 0
      eave_params.group_by { |_, _, wv, dv, lv| [wv.to_a, dv.to_a, lv.to_a].flatten.map { |v| (v.to_mm / 5).round } }.each_value do |list|
        wu = list.first[2].clone; wu.normalize!
        sorted = list.sort_by { |_, o, _, _, _| o.x * wu.x + o.y * wu.y }
        sorted.each_cons(2) do |a, b|
          gap = ((b[1].x - a[1].x) * wu.x + (b[1].y - a[1].y) * wu.y).to_mm
          next unless gap > 2000 && gap < 6000
          k = (gap / 1000.0).round - 1
          k.times do |i|
            off = gap * (i + 1) / (k + 1)
            o = Geom::Point3d.new(a[1].x + wu.x * off.mm, a[1].y + wu.y * off.mm, a[1].z)
            g = a[0].add_group
            g.name = '下屋 垂木(鉄骨・追加)'
            h_member(g.entities, o, a[2], a[3], a[4], steel)
            added += 1
          end
        end
      end
      log << "下屋の垂木を #{added}本追加（約1m間隔）"

      # --- E3. 下屋の屋根を薄い金属屋根に、軒瓦・熨斗瓦を撤去 ---
      roof_m = mat_prefix('15_')
      soffit_m = mat_prefix('02_')
      edge_m = mat_prefix('14_')
      thin = 0
      dead = []
      shita.definition.entities.grep(Sketchup::Group).each do |g|
        if g.name.start_with?('下屋 (')
          unique!(g)
          vs = g.definition.entities.grep(Sketchup::Face).flat_map(&:vertices).uniq.map(&:position)
          next unless vs.size == 8
          bottom_face = g.definition.entities.grep(Sketchup::Face).find do |f|
            f.vertices.all? { |v| vs.none? { |w| (w.x - v.position.x).abs < 0.01 && (w.y - v.position.y).abs < 0.01 && w.z < v.position.z - 0.01 } }
          end
          next unless bottom_face
          base = bottom_face.outer_loop.vertices.map(&:position)
          g.definition.entities.clear!
          faces = prism(g.definition.entities, base, Geom::Vector3d.new(0, 0, EAVE_ROOF_T.mm), edge_m)
          faces.compact.each do |f|
            if f.normal.z > 0.5
              f.material = roof_m; f.back_material = roof_m
            elsif f.normal.z < -0.5
              f.material = soffit_m; f.back_material = soffit_m
            end
          end
          g.name = '下屋 (ガルバリウム鋼板 立平葺)'
          thin += 1
        elsif g.name == '軒瓦' || g.name == '熨斗瓦・雨押え'
          dead << g
        end
      end
      shita.definition.entities.erase_entities(dead) unless dead.empty?
      log << "下屋の屋根 #{thin}面を厚さ #{EAVE_ROOF_T.round} の金属屋根に変更、軒瓦・熨斗瓦 #{dead.size}本を撤去"

      # --- E4. 大屋根 南側の軒（テラス上）に細い鉄骨垂木 ---
      roofg, rtr = find_one('最上階 大屋根 (3寸切妻・東西棟)')
      unique!(roofg)
      rg = roofg.definition.entities.add_group
      rg.name = '大屋根 垂木(鉄骨・追加)'
      rg.transformation = rtr.inverse
      cnt = 0
      x = -500.0
      while x <= 37_700
        if BIG_RAFTER_X.none? { |bx| (bx - x).abs < 600 }
          zs = 13_820.0 # 軒先（y=-850）の軒天高さ。3寸勾配で y=10,750 まで
          o = pt(x - 37.5, -850, zs - 150)
          h_member(rg.entities, o, Geom::Vector3d.new(75.mm, 0, 0), Geom::Vector3d.new(0, 0, 150.mm),
                   Geom::Vector3d.new(0, 11_600.mm, (11_600 * 0.3).mm), steel)
          cnt += 1
        end
        x += 1000.0
      end
      log << "大屋根 南側の軒に鉄骨垂木（H-150×75）を #{cnt}本追加（約1m間隔）"

      # --- E5. 材料の色（柱・梁・サッシ・軒天・下屋屋根） ---
      MAT_RECOLOR.each do |prefix, name, rgb|
        m = mat_prefix(prefix)
        next unless m
        m.texture = nil if m.respond_to?(:texture=)
        m.color = Sketchup::Color.new(*rgb)
        m.name = name
      end
      log << '材料: 柱・梁=鉄骨グレー、サッシ=ダークグレー、軒天=スチールのライトグレー、下屋屋根=ガルバリウム ダークグレー、' \
             '各階の木の帯=鋼板スパンドレル ダークグレー'
      model.set_attribute(MARK_DICT, 'steel_done', true)
    else
      log << '（鉄骨化・軒の変更は実行済みのためスキップ）'
    end

    # --- E6. 吹抜けの手摺をエキスパンドメタル調に ---
    mesh = new_mat(:mesh)
    map = {}
    glass = mat_prefix('11_')
    cap = mat_prefix('05_')
    map[glass] = mesh if glass
    map[cap] = steel if cap
    targets = find_named('南東階段 手摺').map(&:first) + find_named('南側吹抜け 手摺(2F)').map(&:first)
    ext, etr = find_named('外部階段 (1F→2F) ・ 歩道橋接続').first
    (ext ? ext.definition.entities : []).each do |e|
      next unless container?(e)
      mn, mx = world_bb_mm(e, etr)
      targets << e if mn && mn[0] >= 4_900 && mx[0] <= 13_500 && mn[1] >= 27_100 && mx[1] <= 44_960 && mn[2] >= 4_990
    end
    targets.each { |t| unique!(t); recolor_tree(t, map) }
    log << "吹抜けまわりの手摺 #{targets.size}グループをエキスパンドメタル調（グレー・半透明）に"

    # --- E7. 家具 ---
    # 既存の家具グループは、ユーザーがグループ化して移動していても探して作り直す（同じ場所に作る）
    old_hits = find_named('家具（せせらぎ館風）')
    if old_hits.empty?
      bld = model.entities.find { |e| container?(e) && e.name.start_with?(BUILDING_PREFIX) }
      fents = bld.definition.entities
      ftr = bld.transformation
    else
      o, ot = old_hits.first
      par = o.parent
      fents = par.respond_to?(:entities) ? par.entities : par
      ftr = ot * o.transformation.inverse
      old_hits.each { |g, _| g.erase! if g.valid? }
    end
    fg = fents.add_group
    fg.name = '家具（せせらぎ館風）'
    fg.transformation = ftr.inverse
    tdef, cdef, bdef = furniture_defs
    ztab = { '1F' => 0.0, '2F' => 5000.0, '3F' => 9500.0 }
    TABLES.each do |fl, x, y|
      z = ztab[fl] + 8.0 # 床仕上げの上
      fg.entities.add_instance(tdef, Geom::Transformation.translation(Geom::Vector3d.new(x.mm, y.mm, z.mm)))
      [-450, 450].each do |dx|
        fg.entities.add_instance(cdef, Geom::Transformation.translation(Geom::Vector3d.new((x + dx).mm, (y + 675).mm, z.mm)))
        fg.entities.add_instance(cdef, Geom::Transformation.translation(Geom::Vector3d.new((x + dx).mm, (y - 675).mm, z.mm)) *
                                       Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), Math::PI))
      end
    end
    BENCHES.each do |fl, x, y|
      fg.entities.add_instance(bdef, Geom::Transformation.translation(Geom::Vector3d.new(x.mm, y.mm, (ztab[fl] + 8.0).mm)))
    end
    log << "家具: テーブル #{TABLES.size}台・椅子 #{TABLES.size * 4}脚・ベンチ #{BENCHES.size}台"

    model.commit_operation
    puts "[STEP E 完了]\n  " + log.join("\n  ")
    log
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP E でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
  end

  # 家具のコンポーネント（テーブル W1800×D800×H720、椅子、ベンチ W1800×D450×H420）
  def furniture_defs
    top = new_mat(:t_top)
    leg = new_mat(:t_leg)
    wood = new_mat(:chair)
    fab = new_mat(:bench)
    t = model.definitions['TF_テーブル_W1800xD800'] || begin
      d = model.definitions.add('TF_テーブル_W1800xD800')
      e = d.entities
      box(e, -900, -400, 695, 900, 400, 720, top)
      [-840, 800].each do |x0|
        [-360, 320].each { |y0| box(e, x0, y0, 0, x0 + 40, y0 + 40, 695, leg) }
        box(e, x0, -320, 0, x0 + 40, 320, 40, leg)
        box(e, x0, -320, 655, x0 + 40, 320, 695, leg)
      end
      d
    end
    c = model.definitions['TF_椅子_ブナ'] || begin
      d = model.definitions.add('TF_椅子_ブナ')
      e = d.entities
      box(e, -220, -210, 425, 220, 210, 450, wood)                       # 座面
      [[-215, -205], [185, -205]].each { |x0, y0| box(e, x0, y0, 0, x0 + 30, y0 + 30, 425, wood) } # 前脚
      [[-215, 175], [185, 175]].each { |x0, y0| box(e, x0, y0, 0, x0 + 30, y0 + 30, 820, wood) }   # 後脚（背）
      box(e, -185, 180, 720, 185, 200, 800, wood)                        # 背もたれ
      d
    end
    b = model.definitions['TF_ベンチ_W1800xD450'] || begin
      d = model.definitions.add('TF_ベンチ_W1800xD450')
      e = d.entities
      box(e, -900, -225, 320, 900, 225, 420, fab)
      [[-860, -185], [820, -185], [-860, 145], [820, 145]].each { |x0, y0| box(e, x0, y0, 0, x0 + 40, y0 + 40, 320, leg) }
      d
    end
    [t, c, b]
  end

  # ===========================================================================
  # STEP F: 軒と屋根（田園調布せせらぎ館の写真を参考）
  #   ・大屋根: 屋根板を薄く（端部 450→150）し、その下に細い垂木（100×300 @約600）を見せる。
  #            軒先の垂木の間に白い面戸。妻壁の上端はすき間を土壁で埋める。
  #   ・下屋: 垂木を小さな角形の持ち出し材（100×150 @約1000）に作り直し、
  #           下屋まわりの鉄骨（柱・梁・垂木）を明るいシャンパングレーに。屋根は明るいグレー。
  # ===========================================================================
  ROOF_OLD_T = 450.0
  ROOF_NEW_T = 150.0
  RAFTER_W = 100.0
  RAFTER_PITCH = 600.0
  EAVE_RAFTER_W = 100.0
  EAVE_RAFTER_D = 150.0
  EAVE_RAFTER_PITCH = 1000.0
  ROOF_MATS = {
    rafter: ['TF_大屋根_垂木_ダーク #2F3134', [47, 49, 52]],
    soffit: ['TF_大屋根_軒天_ダーク #3A3C3F', [58, 60, 63]],
    menndo: ['TF_大屋根_面戸_白 #E9E7E2', [233, 231, 226]],
    eave:   ['TF_下屋_鉄骨_シャンパングレー #B3AB9D', [179, 171, 157]]
  }.freeze

  def roof_mat(key)
    name, rgb = ROOF_MATS[key]
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  # 平面 [a,b,c,d]（インチ）上の (x,y) の高さ（mm）
  def plane_z_mm(pl, x_mm, y_mm)
    a, b, c, d = pl
    -(a * x_mm.mm + b * y_mm.mm + d) / c * 25.4
  end

  def step_f_roof
    if model.get_attribute(MARK_DICT, 'roof2_done')
      puts 'STEP F は実行済みのためスキップしました。'
      return
    end
    model.start_operation('軒・屋根（せせらぎ館の写真を参考）', true)
    log = []
    roofg, rtr = find_one('最上階 大屋根 (3寸切妻・東西棟)')
    unique!(roofg)
    rents = roofg.definition.entities
    dark_soffit = roof_mat(:soffit)
    edge_m = mat_prefix('14_')
    roof_top_m = mat_prefix('01_')

    # --- F1. 大屋根の屋根板を薄く ---
    planes = []
    %w[大屋根\ 南面 大屋根\ 北面].each do |nm|
      g = rents.find { |e| e.is_a?(Sketchup::Group) && e.name == nm }
      next unless g
      unique!(g)
      top = g.definition.entities.grep(Sketchup::Face).max_by { |f| f.normal.transform(g.transformation).z }
      t = g.transformation
      pts = top.outer_loop.vertices.map { |v| v.position.transform(t) }
      nrm = pts[0].vector_to(pts[1]).cross(pts[0].vector_to(pts[2]))
      nrm.normalize!
      nrm.reverse! if nrm.z < 0
      pl = [nrm.x, nrm.y, nrm.z, -nrm.dot(Geom::Vector3d.new(pts[0].x, pts[0].y, pts[0].z))]
      xs = pts.map { |p| p.x.to_mm }
      ys = pts.map { |p| p.y.to_mm }
      planes << { name: nm, pl: pl, poly: pts.map { |p| [p.x.to_mm, p.y.to_mm] }, ymin: ys.min, ymax: ys.max, xmin: xs.min, xmax: xs.max }
      g.definition.entities.clear!
      g.transformation = Geom::Transformation.new
      faces = prism(g.definition.entities, pts, Geom::Vector3d.new(0, 0, -ROOF_NEW_T.mm), edge_m)
      faces.compact.each do |f|
        if f.normal.z > 0.5 then f.material = roof_top_m; f.back_material = roof_top_m
        elsif f.normal.z < -0.5 then f.material = dark_soffit; f.back_material = dark_soffit
        end
      end
    end
    raise '大屋根の屋根面が見つかりません' if planes.size < 2
    gap = ROOF_OLD_T - ROOF_NEW_T
    log << "大屋根の屋根板を #{ROOF_OLD_T.round}→#{ROOF_NEW_T.round} に（軒天はダークグレー）"

    plane_at = lambda do |x, y|
      planes.find { |p| y >= p[:ymin] - 1 && y <= p[:ymax] + 1 && x >= p[:xmin] - 1 && x <= p[:xmax] + 1 && point_in_poly?(p[:poly], x, y) } ||
        planes.min_by { |p| [(y - p[:ymin]).abs, (y - p[:ymax]).abs].min }
    end

    # --- F2. 妻壁の上端のすき間を土壁で埋める ---
    earth = mat_prefix('03_')
    filled = 0
    find_named(GABLE_GROUP).each do |gg, gtr|
      unique!(gg)
      ents = gg.definition.entities
      ents.grep(Sketchup::Edge).to_a.each do |e|
        a, b = e.vertices.map { |v| v.position.transform(gtr) }
        on = [a, b].all? do |p|
          pa = plane_at.call(p.x.to_mm, p.y.to_mm)
          (plane_z_mm(pa[:pl], p.x.to_mm, p.y.to_mm) - ROOF_OLD_T - p.z.to_mm).abs < 5
        end
        next unless on && e.faces.size == 1
        inv = gtr.inverse
        q = [a, b, b.offset(Geom::Vector3d.new(0, 0, gap.mm)), a.offset(Geom::Vector3d.new(0, 0, gap.mm))].map { |p| p.transform(inv) }
        f = ents.add_face(q)
        next unless f
        f.material = earth; f.back_material = earth
        filled += 1
      end
    end
    log << "妻壁の上端 #{filled}か所を土壁で延長（すき間 #{gap.round}）"

    # --- F3. 垂木（100×300 @約600）と面戸 ---
    old = rents.select { |e| e.is_a?(Sketchup::Group) && ['大屋根 垂木(鉄骨・追加)', '大屋根 垂木(写真2)'].include?(e.name) }
    rents.erase_entities(old) unless old.empty?
    rg = rents.add_group
    rg.name = '大屋根 垂木(写真2)'
    rg.transformation = rtr.inverse
    raf = roof_mat(:rafter)
    white = roof_mat(:menndo)
    x0 = planes.map { |p| p[:xmin] }.min
    x1 = planes.map { |p| p[:xmax] }.max
    n = ((x1 - x0 - RAFTER_W) / RAFTER_PITCH).round
    pitch = (x1 - x0 - RAFTER_W) / n
    cnt = 0
    blocks = 0
    planes.each do |p|
      (0..n).each do |i|
        xa = x0 + i * pitch
        xc = xa + RAFTER_W / 2
        ivs = y_intervals(p[:poly], xc)
        ivs.each do |ya, yb|
          za = plane_z_mm(p[:pl], xc, ya) - ROOF_OLD_T
          zb = plane_z_mm(p[:pl], xc, yb) - ROOF_OLD_T
          prof = [pt(xa, ya, za), pt(xa + RAFTER_W, ya, za), pt(xa + RAFTER_W, ya, za + gap), pt(xa, ya, za + gap)]
          sub = rg.entities.add_group
          prism(sub.entities, prof, Geom::Vector3d.new(0, (yb - ya).mm, (zb - za).mm), raf)
          cnt += 1
          next if i == n
          # 軒先（低い側の端）の垂木間に白い面戸
          ylow = za < zb ? ya : yb
          dir = za < zb ? 1 : -1
          zt = [za, zb].min + gap # 軒先での屋根板の下端
          bx0 = xa + RAFTER_W + (pitch - RAFTER_W - 200) / 2.0
          y0b, y1b = [ylow, ylow + dir * 100].minmax
          box(rg.entities, bx0, y0b, zt - 100, bx0 + 200, y1b, zt - 10, white)
          blocks += 1
        end
      end
    end
    log << "大屋根の下に垂木 #{cnt}本（100×300、ピッチ約#{pitch.round}）、軒先の面戸 #{blocks}個"

    # --- F4. 下屋: 垂木を小さな持ち出し材に作り直し、鉄骨をシャンパングレーに ---
    shita, = find_one('1F 下屋 (南・西・北3m / 東0.6m)')
    unique!(shita)
    eave_m = roof_mat(:eave)
    tg = shita.definition.entities.grep(Sketchup::Group).find { |e| e.name == '下屋 繋ぎ梁・垂木' }
    removed = 0
    if tg
      unique!(tg)
      dead = tg.definition.entities.grep(Sketchup::Group).select do |e|
        mn, mx = world_bb_mm(e, tg.transformation)
        mn && mn[2] >= 3_700 && mx[2] <= 5_000
      end
      tg.definition.entities.erase_entities(dead) unless dead.empty?
      removed = dead.size
    end
    made = 0
    shita.definition.entities.grep(Sketchup::Group).each do |slab|
      next unless slab.name.start_with?('下屋 (')
      bot = slab.definition.entities.grep(Sketchup::Face).min_by { |f| f.normal.z }
      next unless bot && bot.normal.z < -0.5
      ps = bot.outer_loop.vertices.map { |v| v.position.transform(slab.transformation) }
      zmax = ps.map(&:z).max
      zmin = ps.map(&:z).min
      up = ps.select { |q| (q.z - zmax).abs < 0.05 }
      lo = ps.select { |q| (q.z - zmin).abs < 0.05 }
      next if up.size < 2 || lo.size < 2
      u = up[0].vector_to(up[1]); u.z = 0; u.normalize!
      proj = ->(q) { q.x * u.x + q.y * u.y }
      ua = up.map(&proj).minmax
      la = lo.map(&proj).minmax
      t0 = [ua[0], la[0]].max
      t1 = [ua[1], la[1]].min
      next if (t1 - t0).to_mm < 300
      d = up[0].vector_to(lo[0]); d = d - Geom::Vector3d.new(u.x * d.dot(u), u.y * d.dot(u), 0) # 斜面方向（軒先へ）
      len_t = (t1 - t0).to_mm
      k = [(len_t / EAVE_RAFTER_PITCH).round, 1].max
      step = len_t / k
      k.times do |i|
        tc = t0 + ((i + 0.5) * step).mm
        base = up[0].offset(Geom::Vector3d.new(u.x * (tc - proj.call(up[0]) - (EAVE_RAFTER_W / 2).mm), u.y * (tc - proj.call(up[0]) - (EAVE_RAFTER_W / 2).mm), 0))
        o = base.offset(Geom::Vector3d.new(0, 0, -EAVE_RAFTER_D.mm))
        prof = [o, o.offset(Geom::Vector3d.new(u.x * EAVE_RAFTER_W.mm, u.y * EAVE_RAFTER_W.mm, 0)),
                o.offset(Geom::Vector3d.new(u.x * EAVE_RAFTER_W.mm, u.y * EAVE_RAFTER_W.mm, EAVE_RAFTER_D.mm)),
                o.offset(Geom::Vector3d.new(0, 0, EAVE_RAFTER_D.mm))]
        g = shita.definition.entities.add_group
        g.name = '下屋 垂木(写真1)'
        prism(g.entities, prof, d, eave_m)
        made += 1
      end
    end
    # 下屋まわりの鉄骨（柱・繋ぎ梁・鼻先の梁）をシャンパングレーに
    steel = mat_prefix('06_')
    recol = 0
    shita.definition.entities.grep(Sketchup::Group).each do |g|
      next if g.name.start_with?('下屋 (') || g.name == '下屋 繋ぎ梁・垂木' || g.name == '下屋 垂木(写真1)'
      fs = g.definition.entities.grep(Sketchup::Face)
      next unless g.material == steel || fs.any? { |f| f.material == steel }
      g.material = eave_m if g.material == steel
      fs.each { |f| f.material = eave_m if f.material == steel; f.back_material = eave_m if f.back_material == steel }
      recol += 1
    end
    roof15 = mat_prefix('15_')
    if roof15
      roof15.color = Sketchup::Color.new(168, 164, 157)
      roof15.name = '15_屋根_ガルバリウム立平_ライトグレー #A8A49D'
    end
    log << "下屋: 垂木 #{removed}本を撤去し、持ち出し材（100×150）を #{made}本作成。鉄骨 #{recol}本をシャンパングレーに、屋根を明るいグレーに"

    model.set_attribute(MARK_DICT, 'roof2_done', true)
    model.commit_operation
    puts "[STEP F 完了]\n  " + log.join("\n  ")
    log
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP F でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
  end

  def point_in_poly?(poly, x, y)
    inside = false
    poly.each_with_index do |(x0, y0), i|
      x1, y1 = poly[(i + 1) % poly.size]
      next if (y0 > y) == (y1 > y)
      xi = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
      inside = !inside if x < xi
    end
    inside
  end

  # 多角形 poly（mm）を鉛直線 x で切ったときの y 区間
  def y_intervals(poly, x)
    ys = []
    poly.each_with_index do |(x0, y0), i|
      x1, y1 = poly[(i + 1) % poly.size]
      next if (x0 - x1).abs < 1e-6
      lo, hi = [x0, x1].minmax
      next unless x > lo && x < hi
      ys << y0 + (x - x0) * (y1 - y0) / (x1 - x0)
    end
    ys.sort.each_slice(2).map { |a, b| [a, b] }.select { |_, b| b }
  end

  # ===========================================================================
  # STEP G: 屋根まわりの鉄骨の見え方
  #   ・妻側（ケラバ）の登り梁は装飾材のため、木製の角材（05 木地）にする
  #   ・南北の軒で柱より外に出ている H形鋼を、柱の内面より奥へ下げる
  #       南: 桁（大屋根の桁とその下の梁）を柱の内面 Y=250 の奥へ移動し、
  #           登り梁・繋ぎ梁の南端を Y=250 で切る
  #       北: 登り梁の北端を柱の内面 Y=56,450 で切る
  #   ・軒の出（柱より外）は STEP F の細い垂木と面戸だけが見える
  #   ・何度実行しても同じ結果になる（移動・切断済みの部材は変更しない）
  # ===========================================================================
  SOUTH_HIDE_Y = 250.0      # 南側の柱（□500、芯 Y0）の内面
  NORTH_HIDE_Y = 56_450.0   # 北側の柱（□500、芯 Y56,700）の内面
  VERGE_X = [-300.0, 37_500.0].freeze # この範囲より外（妻壁の外）にある登り梁が妻側の装飾材
  ROOF_EDGE_X = [-850.0, 38_050.0].freeze # 大屋根の妻側の端（ケラバ）
  VERGE_W = 150.0           # 妻側の木の登り梁の幅（ケラバの端に揃える）
  ROOF_STEEL_Z = 12_000.0   # これより高い部材だけを対象にする（下屋の 1F 部分は対象外）
  ROOF_MEMBER_GROUPS = ['大屋根 桁・梁', '大屋根 棟木・登り梁', '下屋 繋ぎ梁・垂木'].freeze

  # 部材グループ（角材または H形鋼の押し出し形状）の両端面を world 座標で返す
  #   戻り値: [端面Aの点列, 端面Bの中心 - 端面Aの中心（長さベクトル）, 材料]
  def member_ends(grp, wtr)
    ents = grp.definition.entities
    faces = ents.grep(Sketchup::Face)
    return nil if faces.size < 6 || ents.any? { |e| container?(e) }
    longest = ents.grep(Sketchup::Edge).max_by { |e| e.vertices[0].position.distance(e.vertices[1].position) }
    return nil unless longest
    axis = longest.vertices[0].position.vector_to(longest.vertices[1].position).transform(wtr)
    axis.normalize!
    # 端面は長さ方向の成分を持つ面（鉛直に切った登り梁の端面も含む）。側面は長さ方向に直交する
    ends = faces.select { |f| f.normal.transform(wtr).normalize!.dot(axis).abs > 0.5 }
    return nil unless ends.size == 2
    a, b = ends.map { |f| f.outer_loop.vertices.map { |v| v.position.transform(wtr) } }
    ca = centroid(a)
    cb = centroid(b)
    [a, ca.vector_to(cb), ends[0].material]
  end

  def centroid(pts)
    n = pts.size.to_f
    Geom::Point3d.new(pts.sum(&:x) / n, pts.sum(&:y) / n, pts.sum(&:z) / n)
  end

  def scale_vec(v, s)
    Geom::Vector3d.new(v.x * s, v.y * s, v.z * s)
  end

  # 端面の点列 pts（world）と長さベクトル lv（world）で部材を作り直す
  def rebuild_member(grp, wtr, pts, lv, material)
    inv = wtr.inverse
    ents = grp.definition.entities
    ents.clear!
    prism(ents, pts.map { |p| p.transform(inv) }, lv.transform(inv), material)
  end

  # 端面 pts を、幅方向（水平）×せい方向の外形の長方形に置き換える
  #   x_span: [x0, x1]（mm）を指定すると幅をその範囲に合わせる。rise: 上端を鉛直にかさ上げする量（mm）
  def envelope_rect(pts, lv, x_span = nil, rise = 0.0)
    nrm = Geom::Vector3d.new(0, 0, 0)
    pts.each_with_index do |a, i|
      b = pts[(i + 1) % pts.size]
      nrm.x += (a.y - b.y) * (a.z + b.z)
      nrm.y += (a.z - b.z) * (a.x + b.x)
      nrm.z += (a.x - b.x) * (a.y + b.y)
    end
    nrm.normalize!
    wu = lv.cross(Geom::Vector3d.new(0, 0, 1))
    wu.normalize!
    du = nrm.cross(wu)
    du.normalize!
    du.reverse! if du.z < 0
    o = pts[0]
    ws = pts.map { |p| o.vector_to(p).dot(wu) }
    ds = pts.map { |p| o.vector_to(p).dot(du) }
    w0, w1 = ws.minmax
    w0, w1 = x_span.map { |x| (x.mm - o.x) / wu.x }.minmax if x_span && wu.x.abs > 0.99
    d0, d1 = ds.minmax
    d1 += rise.mm / du.z if du.z > 0.1
    [[w0, d0], [w1, d0], [w1, d1], [w0, d1]].map do |w, d|
      o.offset(scale_vec(wu, w) + scale_vec(du, d))
    end
  end

  def step_g_roof_steel
    model.start_operation('屋根まわりの鉄骨（妻側を木製に、南北の梁を柱の奥へ）', true)
    log = []
    wood = mat_prefix('05_木格子') || mat_prefix('05_')
    raise '材料「05_」（木地）が見つかりません' unless wood
    verge = 0
    shifted = 0
    trimmed = 0
    ROOF_MEMBER_GROUPS.each do |gname|
      find_named(gname).each do |g, gtr|
        unique!(g)
        g.definition.entities.grep(Sketchup::Group).to_a.each do |m|
          wtr = gtr * m.transformation
          info = member_ends(m, wtr)
          next unless info
          pts, lv, mat = info
          pb = pts.map { |p| p.offset(lv) }
          all = pts + pb
          xs = all.map { |p| p.x.to_mm }
          ys = all.map { |p| p.y.to_mm }
          zs = all.map { |p| p.z.to_mm }
          next if zs.min < ROOF_STEEL_Z
          len_y = lv.y.to_mm
          along_y = len_y.abs > lv.x.to_mm.abs

          # --- G1. 妻側の登り梁 → 木製の角材 ---
          if gname == '大屋根 棟木・登り梁' && (xs.max < VERGE_X[0] || xs.min > VERGE_X[1])
            next if m.definition.entities.grep(Sketchup::Face).size == 6 && mat == wood
            unique!(m)
            # 幅 150 でケラバの端に揃え、上端は屋根板の下面まで（STEP F で屋根板を薄くした分 300 をかさ上げ）
            span = xs.max < VERGE_X[0] ? [ROOF_EDGE_X[0], ROOF_EDGE_X[0] + VERGE_W] : [ROOF_EDGE_X[1] - VERGE_W, ROOF_EDGE_X[1]]
            rebuild_member(m, wtr, envelope_rect(pts, lv, span, ROOF_OLD_T - ROOF_NEW_T), lv, wood)
            m.material = nil
            verge += 1
            next
          end

          # --- G2. 南の桁（X方向の材）を柱の内面の奥へ移動 ---
          if !along_y && ys.max <= SOUTH_HIDE_Y + 1 && ys.min >= -400
            dy = SOUTH_HIDE_Y - ys.min
            mv = Geom::Transformation.translation(Geom::Vector3d.new(0, dy.mm, 0))
            m.transformation = gtr.inverse * mv * gtr * m.transformation
            shifted += 1
            next
          end

          # --- G3. Y方向の材の南端・北端を柱の内面で切る ---
          next unless along_y
          if len_y < 0
            pts = pb
            lv = lv.reverse
            len_y = -len_y
          end
          ya = pts.map { |p| p.y.to_mm }.min           # 南端（端面の最も外側）
          yb = pts.map { |p| p.offset(lv).y.to_mm }.max # 北端
          s0 = ya < SOUTH_HIDE_Y - 1 && yb > SOUTH_HIDE_Y + 100 ? (SOUTH_HIDE_Y - ya) / len_y : 0.0
          s1 = yb > NORTH_HIDE_Y + 1 && ya < NORTH_HIDE_Y - 100 ? (yb - NORTH_HIDE_Y) / len_y : 0.0
          next if s0.zero? && s1.zero?
          unique!(m)
          rebuild_member(m, wtr, pts.map { |p| p.offset(scale_vec(lv, s0)) }, scale_vec(lv, 1.0 - s0 - s1), mat)
          trimmed += 1
        end
      end
    end
    log << "妻側の登り梁 #{verge}本を木製の角材（#{wood.name}）に変更"
    log << "南側の桁 #{shifted}本を柱の内面（Y=#{SOUTH_HIDE_Y.round}）の奥へ移動"
    log << "登り梁・繋ぎ梁 #{trimmed}本の端部を柱の内面（南 Y=250 / 北 Y=56,450）で切断"
    model.commit_operation
    puts "[STEP G 完了]\n  " + log.join("\n  ")
    log
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP G でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
  end

  # ===========================================================================
  # STEP H: 上司の意見（2026-10-06）
  #   H1. 大屋根の軒天を明るく（案B: 鉄骨の垂木はそのまま、軒天の色だけ下屋と同じライトグレーに）
  #   H2. 1階の軒（下屋）の柱を木の丸柱に（鉄骨の柱を集成材で包む。足元は鉄骨を見せる）
  #   H3. ブリッジ（歩道橋 接続デッキ）と歩道橋本体の床を木目調塩ビシート NS8402 に
  #   H4. ブリッジの手摺を木目調アルミの縦格子（NS8403 の色）に作り直す
  #   H5. ブリッジと歩道橋本体の取り合いに EXP.J カバー（床・手摺部）
  #   H6. 歩道橋本体の手摺をアルミ（グレー）に
  #   H0/H7. 下屋の鼻先の梁を垂木の下まで下げ（垂木が梁に載る）、角部に隅木と配付垂木を追加
  #   ・何度実行しても同じ結果になる（作ったグループは名前で探して作り直す）
  # ===========================================================================
  H_MATS = {
    soffit:  ['TF_大屋根_軒天_ライトグレー #C4C6C8', [196, 198, 200]],
    floor:   ['TF_床_塩ビシート_木目_NS8402 #B19880', [177, 152, 128]],
    rail:    ['TF_手摺_木目調アルミ_NS8403 #948173', [148, 129, 115]],
    expj:    ['TF_EXPJカバー_アルミ_シルバー #B8BBBE', [184, 187, 190]],
    walk_rail: ['TF_歩道橋手摺_アルミ_グレー #9EA2A6', [158, 162, 166]]
  }.freeze
  EAVE_COL_D = 229.4        # 木の丸柱の直径（指定値）
  EAVE_CORE_D = 139.8       # 中の鉄骨（鋼管 φ139.8。H形 240×120 は φ229.4 の外にはみ出すため置き換える）
  EAVE_COL_FOOT = 300.0     # 柱の下端から木の下端まで（鉄骨の柱脚を見せる。地面から約150）
  EAVE_COL_SIDES = 24
  EAVE_COL_GROUP = '下屋 柱 木被覆(丸柱)'.freeze
  BRIDGE_DECK = '歩道橋 接続デッキ'.freeze
  BRIDGE_BOX = { x0: -6_000.0, x1: 4_760.0, y0: 3_590.0, y1: 6_110.0 }.freeze # ブリッジの範囲（平面）
  BRIDGE_RAIL_Y = [3_652.0, 6_052.0].freeze # 手摺の芯（既存の手摺子の芯）
  BRIDGE_RAIL_GROUP = 'ブリッジ 手摺(木目調アルミ NS8403)'.freeze
  RAIL_H = 1_100.0          # 手摺高さ（2階以上のバルコニー等は 1.1m 以上: 建築基準法施行令126条）
  BALUSTER_W = 30.0         # 縦格子の見付（手摺の方向）
  BALUSTER_D = 50.0         # 縦格子の見込
  BALUSTER_PITCH = 100.0    # 縦格子の間隔（すき間 70 ≦ 110）
  CAP_W = 60.0
  CAP_H = 40.0
  EXPJ_X = -6_002.0         # 歩道橋本体（〜X−6,010）とブリッジ（X−5,994〜）の境
  EXPJ_W = 600.0            # カバーの幅（遊間 約200〜400 ＋ 両側の掛かり。1m は免震用の規模）
  EXPJ_GROUP = 'ブリッジ EXP.J カバー'.freeze
  WALKWAY_BOX = { x0: -25_200.0, x1: -5_990.0, y0: 0.0, y1: 28_000.0, z0: 100.0, z1: 4_960.0 }.freeze # 歩道橋本体の床を探す範囲
  WALKWAY_MIN_W = 1_000.0   # 幅がこれ未満の面（笠木・縁石・橋脚の天端）は床とみなさない
  WALK_RAIL_BOX = { x0: -25_200.0, x1: -5_990.0, y0: 0.0, y1: 28_000.0, z0: -1_000.0, z1: 6_100.0 }.freeze # 歩道橋本体の手摺を探す範囲
  WALK_RAIL_MAX_T = 150.0   # 平面の細い方の寸法がこれ以下の部材を手摺（手摺子・支柱・笠木・手すり）とみなす（桁・立上りは 200 以上）

  # 円柱（world 座標 mm で指定。inv を渡すとその座標系に変換して作る）。側面の縦の辺はなめらかにする
  def round_prism(ents, cx, cy, z0, h, r, material, inv = nil)
    pts = (0...EAVE_COL_SIDES).map do |i|
      a = 2 * Math::PI * i / EAVE_COL_SIDES
      pt(cx + r * Math.cos(a), cy + r * Math.sin(a), z0)
    end
    vec = Geom::Vector3d.new(0, 0, h.mm)
    if inv
      pts = pts.map { |q| q.transform(inv) }
      vec = vec.transform(inv)
    end
    faces = prism(ents, pts, vec, material)
    faces.compact.each do |f|
      next if f.normal.z.abs > 0.5 || !f.respond_to?(:edges)
      f.edges.each do |ed|
        next unless ed.respond_to?(:soft=)
        a, b = ed.vertices.map(&:position)
        next unless (a.x - b.x).abs < 0.01 && (a.y - b.y).abs < 0.01
        ed.soft = true
        ed.smooth = true
      end
    end
    faces
  end

  # 子のグループを持たない（面だけの）グループ／コンポーネントを順に渡す。yield(entity, 親の world 変換)
  def each_leaf(ents, tr, skip_prefix = ['外構'], &blk)
    ents.each do |e|
      next unless container?(e)
      next if skip_prefix.any? { |sp| e.name.start_with?(sp) }
      kids = e.definition.entities
      if kids.any? { |c| container?(c) }
        each_leaf(kids, tr * e.transformation, skip_prefix, &blk)
      elsif kids.any? { |c| c.is_a?(Sketchup::Face) }
        blk.call(e, tr)
      end
    end
  end

  # 下屋の屋根板（グループ）の下面: 点列・平面の高さ関数・軒先側／壁側の辺（下屋グループの座標）
  def slab_frame(slab)
    t = slab.transformation
    bot = slab.definition.entities.grep(Sketchup::Face).min_by { |f| f.normal.transform(t).z }
    return nil unless bot
    nrm = bot.normal.transform(t)
    nrm.normalize!
    return nil unless nrm.z < -0.5
    ps = bot.outer_loop.vertices.map { |v| v.position.transform(t) }
    p0 = ps.first
    zmax = ps.map(&:z).max
    zmin = ps.map(&:z).min
    {
      poly: ps.map { |q| [q.x.to_mm, q.y.to_mm] },
      z_at: ->(x, y) { p0.z.to_mm - (nrm.x * (x - p0.x.to_mm) + nrm.y * (y - p0.y.to_mm)) / nrm.z },
      up: ps.select { |q| (q.z - zmax).abs < 0.05 },
      lo: ps.select { |q| (q.z - zmin).abs < 0.05 }
    }
  end

  def h_mat(key)
    name, rgb = H_MATS[key]
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  # 上向きの面（world 法線 z > 0.9）を探す。yield(face, world_points) が true の面を返す
  def up_faces(ents, tr, out = [], skip_prefix = ['外構'], &blk)
    ents.each do |e|
      if container?(e)
        next if skip_prefix.any? { |s| e.name.start_with?(s) }
        up_faces(e.definition.entities, tr * e.transformation, out, skip_prefix, &blk)
      elsif e.is_a?(Sketchup::Face)
        n = e.normal.transform(tr)
        next if n.length < 1e-9
        n.normalize!
        next unless n.z > 0.9
        pts = e.outer_loop.vertices.map { |v| v.position.transform(tr) }
        out << e if blk.call(e, pts)
      end
    end
    out
  end

  def paint(face, m)
    face.material = m
    face.back_material = m
  end

  def step_h_review
    model.start_operation('上司の意見（軒天・木の丸柱・ブリッジ）', true)
    log = []

    # --- H1. 大屋根の軒天を明るく ---
    soff = model.materials.find { |m| m.name.start_with?('TF_大屋根_軒天') }
    if soff
      name, rgb = H_MATS[:soffit]
      soff.color = Sketchup::Color.new(*rgb)
      soff.name = name unless soff.name == name
      log << "大屋根の軒天を #{name} に（下屋の軒天と同じ色）"
    else
      log << '（スキップ）大屋根の軒天の材料（TF_大屋根_軒天…）が見つかりません'
    end

    # --- H2. 1階の軒の柱を木の丸柱に ---
    shita, str = find_one('1F 下屋 (南・西・北3m / 東0.6m)')
    unique!(shita)
    sents = shita.definition.entities
    old = sents.select { |e| e.is_a?(Sketchup::Group) && e.name == EAVE_COL_GROUP }
    sents.erase_entities(old) unless old.empty?
    eave_m = model.materials.find { |m| m.name.start_with?('TF_下屋_鉄骨') }

    # --- H0. 垂木が梁の上に載るように、下屋の鼻先の梁を下げる（梁の上端 = 垂木の下端） ---
    slabs = sents.grep(Sketchup::Group).select { |g| g.name.start_with?('下屋 (') }.map { |g| slab_frame(g) }.compact
    beams = []
    lowered = 0
    sents.grep(Sketchup::Group).each do |g|
      next if g.name.start_with?('下屋 ') || g.name == EAVE_COL_GROUP
      bb = g.bounds
      next if bb.empty?
      bmn = bb.min
      bmx = bb.max
      dx = (bmx.x - bmn.x).to_mm
      dy = (bmx.y - bmn.y).to_mm
      dz = (bmx.z - bmn.z).to_mm
      next unless dz < 600 && [dx, dy].max > 2_000 && [dx, dy].min <= 300 && bmn.z.to_mm > 3_000 && bmx.z.to_mm < 5_200
      beams << g
      cx = ((bmn.x + bmx.x) / 2).to_mm
      cy = ((bmn.y + bmx.y) / 2).to_mm
      sl = slabs.find { |f| point_in_poly?(f[:poly], cx, cy) }
      next unless sl # 下屋の屋根の外（建物側の梁）は対象外
      diff = bmx.z.to_mm - (sl[:z_at].call(cx, cy) - EAVE_RAFTER_D)
      next unless diff > 1
      g.transformation = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -diff.mm)) * g.transformation
      lowered += 1
    end
    beam_bbs = beams.map { |g| world_bb_mm(g, str) }.compact
    log << "下屋の鼻先の梁 #{lowered}本を、垂木（#{EAVE_RAFTER_W.round}×#{EAVE_RAFTER_D.round}）の下端まで下げた（垂木が梁の上に載る）"

    cols = []
    sents.grep(Sketchup::Group).each do |g|
      mn, mx = world_bb_mm(g, str)
      next unless mn
      next unless mx[2] - mn[2] > 2_500 && mx[0] - mn[0] < 400 && mx[1] - mn[1] < 400 && mn[2] < 100 && mx[2] < 5_500
      cols << [g, mn, mx]
    end
    # 同じ位置に重なっている柱は1本にする（下屋の色の柱を残す）
    cols.sort_by! { |g, _, _| g.definition.entities.grep(Sketchup::Face).any? { |f| f.material == eave_m } ? 0 : 1 }
    keep = []
    dup = []
    cols.each do |c|
      if keep.any? { |k| (0..2).all? { |i| (k[1][i] - c[1][i]).abs < 5 && (k[2][i] - c[2][i]).abs < 5 } }
        dup << c[0]
      else
        keep << c
      end
    end
    sents.erase_entities(dup) unless dup.empty?
    wood = mat_prefix('05_木格子') || mat_prefix('05_')
    wg = sents.add_group
    wg.name = EAVE_COL_GROUP
    wg.transformation = str.inverse
    keep.each do |g, mn, mx|
      cx = (mn[0] + mx[0]) / 2.0
      cy = (mn[1] + mx[1]) / 2.0
      # 柱の上端は、上に載る梁の下端に合わせる（H0 で梁を下げた分だけ短くなる）
      above = beam_bbs.find do |bmn, bmx|
        cx.between?(bmn[0] - 150, bmx[0] + 150) && cy.between?(bmn[1] - 150, bmx[1] + 150) &&
          bmn[2] <= mx[2] + 50 && bmn[2] >= mx[2] - 400
      end
      mx = [mx[0], mx[1], above[0][2]] if above
      # 中の鉄骨を鋼管 φ139.8 に作り直す（柱の位置・高さはそのまま）
      core_m = g.definition.entities.grep(Sketchup::Face).first&.material || eave_m
      unique!(g)
      gents = g.definition.entities
      gents.clear!
      round_prism(gents, cx, cy, mn[2], mx[2] - mn[2], EAVE_CORE_D / 2.0, core_m, (str * g.transformation).inverse)
      # 木の丸柱（足元は鉄骨を見せる）
      z0 = mn[2] + EAVE_COL_FOOT
      round_prism(wg.entities.add_group.entities, cx, cy, z0, mx[2] - z0, EAVE_COL_D / 2.0, wood)
    end
    log << "1階の軒の柱 #{keep.size}本を木の丸柱（φ#{EAVE_COL_D}、#{wood.name}）に。中の鉄骨は鋼管 φ#{EAVE_CORE_D} に置き換え、" \
           "足元 #{EAVE_COL_FOOT.round} は鉄骨を見せる。重なっていた柱 #{dup.size}本を削除"

    # --- H7. 下屋の角部（隅棟の下）に配付垂木と隅木を追加 ---
    old = sents.select { |e| e.is_a?(Sketchup::Group) && ['下屋 垂木(角部)', '下屋 隅木'].include?(e.name) }
    sents.erase_entities(old) unless old.empty?
    jack = 0
    hips = {}
    zd = Geom::Vector3d.new(0, 0, EAVE_RAFTER_D.mm)
    slabs.each do |sl|
      up = sl[:up]
      lo = sl[:lo]
      next if up.size < 2 || lo.size < 2
      u = up[0].vector_to(up[1]); u.z = 0; u.normalize!
      proj = ->(q) { q.x * u.x + q.y * u.y }
      ua = up.map(&proj).minmax
      la = lo.map(&proj).minmax
      t0 = [ua[0], la[0]].max
      t1 = [ua[1], la[1]].min
      next if (t1 - t0).to_mm < 300
      d = up[0].vector_to(lo[0]); d = d - Geom::Vector3d.new(u.x * d.dot(u), u.y * d.dot(u), 0) # 斜面方向（軒先へ）
      dlen = d.length.to_mm
      len_t = (t1 - t0).to_mm
      step = len_t / [(len_t / EAVE_RAFTER_PITCH).round, 1].max # STEP F の垂木と同じ間隔
      uw = Geom::Vector3d.new(u.x * EAVE_RAFTER_W.mm, u.y * EAVE_RAFTER_W.mm, 0)
      # 角部の三角形: 低い側は軒先 la[0]〜壁側 ua[0]、高い側は壁側 ua[1]〜軒先 la[1]
      [[:low, la[0], ua[0]], [:high, ua[1], la[1]]].each do |side, a, b|
        next unless (b - a).to_mm > EAVE_RAFTER_W
        # 隅木（隅棟の下、軒先の角から壁側の角まで）。隣の屋根と共有するので1本だけ
        e_pt = side == :low ? lo.min_by(&proj) : lo.max_by(&proj)
        w_pt = side == :low ? up.min_by(&proj) : up.max_by(&proj)
        # 隣の屋根の隅棟とは端点が数十mm ずれることがあるので、軒先の角（±300）で同じ隅木とみなす
        key = [e_pt.x.to_mm, e_pt.y.to_mm]
        unless hips.keys.any? { |k| (k[0] - key[0]).abs < 300 && (k[1] - key[1]).abs < 300 }
          hips[key] = true
          hv = e_pt.vector_to(w_pt)
          wv = Geom::Vector3d.new(-hv.y, hv.x, 0); wv.normalize!
          half = Geom::Vector3d.new(wv.x * (EAVE_RAFTER_W / 2).mm, wv.y * (EAVE_RAFTER_W / 2).mm, 0)
          b0 = e_pt.offset(zd.reverse)
          prof = [b0.offset(half.reverse), b0.offset(half), b0.offset(half).offset(zd), b0.offset(half.reverse).offset(zd)]
          hg = sents.add_group
          hg.name = '下屋 隅木'
          prism(hg.entities, prof, hv, eave_m)
        end
        # 配付垂木（軒先から隅木まで。STEP F の垂木の並びを角部へ延ばす）
        i = 1
        while i < 100
          tc = side == :low ? t0 - ((i - 0.5) * step).mm : t1 + ((i - 0.5) * step).mm
          frac = side == :low ? (tc - a) / (b - a) : (b - tc) / (b - a) # 垂木の長さの割合（壁側の角で1、軒先の角で0）
          break if frac * dlen < 300
          sh = 1.0 - frac
          base = up[0].offset(Geom::Vector3d.new(u.x * (tc - proj.call(up[0]) - (EAVE_RAFTER_W / 2).mm), u.y * (tc - proj.call(up[0]) - (EAVE_RAFTER_W / 2).mm), 0))
          base = base.offset(Geom::Vector3d.new(d.x * sh, d.y * sh, d.z * sh))
          o = base.offset(zd.reverse)
          prof = [o, o.offset(uw), o.offset(uw).offset(zd), o.offset(zd)]
          jg = sents.add_group
          jg.name = '下屋 垂木(角部)'
          prism(jg.entities, prof, Geom::Vector3d.new(d.x * frac, d.y * frac, d.z * frac), eave_m)
          jack += 1
          i += 1
        end
      end
    end
    log << "下屋の角部に隅木 #{hips.size}本と配付垂木 #{jack}本を追加（#{EAVE_RAFTER_W.round}×#{EAVE_RAFTER_D.round}、垂木と同じ間隔）"

    # --- H3. 床を木目調塩ビシート NS8402 に ---
    floor_m = h_mat(:floor)
    deck_hits = find_named(BRIDGE_DECK)
    n_deck = 0
    deck_top = nil
    deck_y = nil
    deck_hits.each do |g, t|
      ups = g.definition.entities.grep(Sketchup::Face).select { |f| f.normal.transform(t).normalize!.z > 0.9 }
      top = ups.max_by { |f| f.vertices.map { |v| v.position.transform(t).z }.max }
      next unless top
      paint(top, floor_m)
      pts = top.outer_loop.vertices.map { |v| v.position.transform(t) }
      # デッキ上面は勾配が付いている（歩道橋側 X−5,994 で低い）ので、面の平面から高さを求める
      nrm = top.normal.transform(t)
      nrm.normalize!
      p0 = pts.first
      deck_top = lambda do |x, y|
        p0.z.to_mm - (nrm.x * (x - p0.x.to_mm) + nrm.y * (y - p0.y.to_mm)) / nrm.z
      end
      deck_y = pts.map { |p| p.y.to_mm }.minmax
      n_deck += 1
    end
    w = WALKWAY_BOX
    walk = up_faces(model.entities, Geom::Transformation.new) do |_f, pts|
      xs = pts.map { |p| p.x.to_mm }
      ys = pts.map { |p| p.y.to_mm }
      zs = pts.map { |p| p.z.to_mm }
      xs.min >= w[:x0] && xs.max <= w[:x1] && ys.min >= w[:y0] && ys.max <= w[:y1] &&
        zs.min >= w[:z0] && zs.max <= w[:z1] && [xs.max - xs.min, ys.max - ys.min].min >= WALKWAY_MIN_W
    end
    walk.each { |f| paint(f, floor_m) }
    log << "床を #{floor_m.name} に: ブリッジ #{n_deck}面、歩道橋本体 #{walk.size}面（通路・スロープ・階段の上向きの面）"
    raise "「#{BRIDGE_DECK}」の上面が見つかりません" unless deck_top

    # --- H4. ブリッジの手摺 ---
    host, htr = find_one('外部階段 (1F→2F) ・ 歩道橋接続')
    unique!(host)
    hents = host.definition.entities
    white = mat_prefix('59_')
    b = BRIDGE_BOX
    dead = hents.select do |e|
      next false unless container?(e)
      if e.name == BRIDGE_RAIL_GROUP || e.name == EXPJ_GROUP
        true
      else
        m = e.material || e.definition.entities.grep(Sketchup::Face).first&.material
        mn, mx = world_bb_mm(e, htr)
        zd = deck_top.call(mn[0], mn[1]) if mn
        m && m == white && mn && mn[0] >= b[:x0] && mx[0] <= b[:x1] && mn[1] >= b[:y0] && mx[1] <= b[:y1] &&
          mn[2] >= zd - 200 && mx[2] <= zd + 1_400
      end
    end
    n_old = dead.count { |e| e.name != BRIDGE_RAIL_GROUP && e.name != EXPJ_GROUP }
    hents.erase_entities(dead) unless dead.empty?
    rail_m = h_mat(:rail)
    rg = hents.add_group
    rg.name = BRIDGE_RAIL_GROUP
    rg.transformation = htr.inverse
    xa = EXPJ_X + EXPJ_W / 2 + 20
    xb = b[:x1] - 10
    nb = 0
    BRIDGE_RAIL_Y.each do |yc|
      za = deck_top.call(xa, yc) + RAIL_H
      zb = deck_top.call(xb, yc) + RAIL_H
      cap = [pt(xa, yc - CAP_W / 2, za - CAP_H), pt(xa, yc + CAP_W / 2, za - CAP_H), pt(xa, yc + CAP_W / 2, za), pt(xa, yc - CAP_W / 2, za)]
      prism(rg.entities, cap, Geom::Vector3d.new((xb - xa).mm, 0, (zb - za).mm), rail_m) # 笠木（デッキの勾配に合わせる）
      x = xa
      while x + BALUSTER_W <= xb
        z0 = deck_top.call(x + BALUSTER_W / 2, yc)
        box(rg.entities, x, yc - BALUSTER_D / 2, z0, x + BALUSTER_W, yc + BALUSTER_D / 2, z0 + RAIL_H - CAP_H, rail_m)
        nb += 1
        x += BALUSTER_PITCH
      end
    end
    log << "ブリッジの手摺: 既存の白い手摺 #{n_old}部材を撤去し、木目調アルミの縦格子 #{nb}本（#{BALUSTER_W.round}×#{BALUSTER_D.round} @#{BALUSTER_PITCH.round}）" \
           "＋笠木 #{CAP_W.round}×#{CAP_H.round}、高さ #{RAIL_H.round} に（#{rail_m.name}）"

    # --- H5. EXP.J カバー ---
    ej = hents.add_group
    ej.name = EXPJ_GROUP
    ej.transformation = htr.inverse
    ex_m = h_mat(:expj)
    x0 = EXPJ_X - EXPJ_W / 2
    x1 = EXPJ_X + EXPJ_W / 2
    yd0, yd1 = deck_y
    zj = deck_top.call(EXPJ_X, (yd0 + yd1) / 2) # 継ぎ目の床の高さ（歩道橋本体と同じ高さ）
    box(ej.entities, x0, yd0, zj, x1, yd1, zj + 6, ex_m) # 床のカバープレート（厚さ6）
    BRIDGE_RAIL_Y.each do |yc|
      box(ej.entities, x0, yc - 40, zj + 6, x1, yc + 40, zj + RAIL_H, ex_m) # 手摺部のカバー（かぶり）
    end
    log << "EXP.J カバー: X #{x0.round}〜#{x1.round}（幅 #{EXPJ_W.round}）、床プレート＋手摺部のカバー（#{ex_m.name}）"

    # --- H6. 歩道橋本体の手摺をアルミ（グレー）に ---
    wr_m = h_mat(:walk_rail)
    q = WALK_RAIL_BOX
    n_rail = 0
    each_leaf(model.entities, Geom::Transformation.new) do |e, ptr|
      mn, mx = world_bb_mm(e, ptr)
      next unless mn
      next unless mn[0] >= q[:x0] && mx[0] <= q[:x1] && mn[1] >= q[:y0] && mx[1] <= q[:y1] && mn[2] >= q[:z0] && mx[2] <= q[:z1]
      next unless [mx[0] - mn[0], mx[1] - mn[1]].min <= WALK_RAIL_MAX_T
      e.material = wr_m
      n_rail += 1
    end
    log << "歩道橋本体の手摺 #{n_rail}部材をアルミ（#{wr_m.name}）に"

    model.commit_operation
    puts "[STEP H 完了]\n  " + log.join("\n  ")
    log
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP H でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
  end

  # ===========================================================================
  # STEP I: サイン（西の妻面に「Takatsuki Common Ground」と高槻市章）、西の妻面のガラス部の木格子
  #   ・上司のスケッチ（10/6）の位置: 棟より北側の妻面、3F の窓の上に文字、その上に市章
  #   ・切り文字（厚さ30）として妻面の木格子の外側に付ける。何度実行しても作り直すだけ
  # ===========================================================================
  SIGN_GROUP = 'サイン（Takatsuki Common Ground・高槻市章）'.freeze
  SIGN_TEXT = 'Takatsuki Common Ground'.freeze
  # フォント: 参考のサイン（庄内コラボセンター）の欧文に字形が近い Windows 標準の Segoe UI を太字で使う
  #   （画像からフォント名は特定できないため近いものを選定。細くしたい場合は SIGN_BOLD = false）
  SIGN_FONT = 'Segoe UI'.freeze
  SIGN_BOLD = true
  SIGN_TEXT_H = 1_300.0       # 文字の高さ（大文字）
  SIGN_TEXT_BASE_Z = 14_400.0 # 文字の下端（ベースライン）。妻面の下端 14,000 の上
  SIGN_TEXT_NORTH_Y = 51_000.0 # 文字の北端（左端）。屋根の下端より下に収まる位置
  SIGN_X = -415.0             # 妻面の木格子の外面（X −405）の外側
  SIGN_DEPTH = 30.0           # 切り文字の厚さ
  SIGN_LOGO_H = 3_300.0       # 市章の高さ
  SIGN_LOGO_CY = 36_000.0     # 市章の中心（Y）
  SIGN_LOGO_BASE_Z = 16_000.0 # 市章の下端
  # 西の妻面のガラス部（棟より南）の木格子: 既存の妻面の木格子と同じ寸法・並び
  GLASS_LATTICE_GROUP = '妻面 ガラス部 木格子'.freeze
  LAT_D = 105.0                   # 見込（既存の木格子と同じ）
  LAT_GAP = 10.0                  # ガラスの外面と格子のすき間
  LAT_W = 44.0                    # 見付
  LAT_PITCH = 360.0               # 既存の木格子（@180）の1本おき（量を半分に）
  LAT_Y0 = -2.0                   # 既存の木格子の並び（Y = −2 + 180×k）
  # 探す範囲: 西の妻面の線（X −405）から、3F の西側の壁の線（X 4,850）まで。棟の少し北（Y 31,000）まで
  GLASS_SEARCH = { x0: -500.0, x1: 5_200.0, y0: 9_000.0, y1: 31_000.0, z0: 13_900.0 }.freeze

  SIGN_MATS = {
    logo: ['TF_サイン_高槻市章_ネイビー #1E2B57', [30, 43, 87]],
    text: ['TF_サイン_文字_チャコール #2B2B2B', [43, 43, 43]]
  }.freeze
  # 高槻市章の輪郭（市章の画像をトレースした多角形。単位は画像のピクセル、左下原点、上向き）
  LOGO_PX_W = 487.0
  LOGO_PX_H = 562.7
  LOGO_OUTER =
    [[243.5, 562.7], [297.5, 469.9], [452.6, 469.2], [321.4, 326.2], [345.5, 312.3], [371.5, 294.4],
     [394.5, 275.4], [420.7, 249.2], [442.6, 222.2], [458.8, 198.2], [476.8, 165.2], [487.0, 141.2],
     [463.5, 143.0], [441.5, 146.9], [422.5, 151.9], [399.5, 159.9], [371.5, 172.8], [353.5, 183.0],
     [334.5, 196.0], [317.5, 210.0], [316.6, 209.2], [318.0, 183.2], [317.0, 163.2], [311.0, 133.2],
     [301.8, 103.2], [289.6, 73.2], [276.7, 48.2], [260.6, 22.2], [243.5, 0.0], [229.2, 18.2], [211.4, 46.2],
     [196.5, 75.2], [184.5, 105.2], [177.4, 128.2], [170.5, 160.2], [169.2, 174.2], [169.9, 210.2],
     [152.5, 196.1], [131.5, 181.9], [109.5, 169.8], [87.5, 160.0], [64.5, 151.9], [45.5, 146.9],
     [23.5, 143.0], [0.0, 141.2], [10.2, 165.2], [26.3, 195.2], [44.3, 222.2], [65.4, 248.2], [88.0, 271.2],
     [111.5, 291.3], [136.6, 309.2], [165.9, 327.2], [34.5, 469.2], [189.5, 469.8]].freeze
  LOGO_HOLES = [
    [[164.5, 422.1], [164.5, 420.8], [218.5, 388.1], [227.5, 400.7], [258.5, 400.9], [268.5, 388.0],
     [323.4, 421.2], [322.5, 422.2]],
    [[229.5, 233.7], [228.6, 232.2], [229.0, 220.2], [232.2, 198.2], [238.0, 177.2], [243.5, 164.5],
     [249.7, 179.2], [254.8, 198.2], [258.6, 232.2], [256.5, 233.8]]
  ].freeze

  # 西の妻面の座標系: ローカル X → 南向き（−Y）、Y → 上、Z → 西（見る人の方）
  def west_gable_axes(y_left, z_base)
    Geom::Transformation.axes(pt(SIGN_X, y_left, z_base), Geom::Vector3d.new(0, -1, 0),
                              Geom::Vector3d.new(0, 0, 1), Geom::Vector3d.new(-1, 0, 0))
  end

  def glass_mat?(m)
    m && ((m.alpha || 1.0) < 0.99 || m.name =~ /ガラス|glass/i)
  end

  # 西の妻面（棟より南）にあるガラスの面を探し、(Y, Z) の多角形（mm）を polys に入れる
  #   範囲（GLASS_SEARCH）に一部でも掛かる面を拾い、格子は範囲内だけに作る。diag には範囲内の全ての面（材料別）を入れる（見つからないときの確認用）
  def gable_glass_faces(ents, tr, inh, polys, diag = Hash.new { |h, k| h[k] = [] })
    q = GLASS_SEARCH
    ents.each do |e|
      if container?(e)
        next if e.name.start_with?('外構') || e.name == GLASS_LATTICE_GROUP
        gable_glass_faces(e.definition.entities, tr * e.transformation, e.material || inh, polys, diag)
      elsif e.is_a?(Sketchup::Face)
        n = e.normal.transform(tr)
        next if n.length < 1e-9
        n.normalize!
        next unless n.x.abs > 0.99
        pts = e.outer_loop.vertices.map { |v| v.position.transform(tr) }
        xs = pts.map { |p| p.x.to_mm }
        ys = pts.map { |p| p.y.to_mm }
        zs = pts.map { |p| p.z.to_mm }
        next unless xs.min >= q[:x0] && xs.max <= q[:x1] && ys.max > q[:y0] && ys.min < q[:y1] && zs.max > q[:z0] + 200
        # 表・裏のどちらかがガラスならガラスの面とみなす（裏面だけガラスにした面もある）
        fm = e.material || inh
        bm = e.back_material || inh
        label = [fm, bm].uniq.map { |m| m ? "#{m.name}（透明度 #{(m.alpha || 1.0).round(2)}）" : '（材料なし）' }.join(' / 裏 ')
        diag[label] << [ys.minmax, zs.minmax, xs.min]
        next unless glass_mat?(fm) || glass_mat?(bm)
        polys << pts.map { |p| [p.y.to_mm, p.z.to_mm] }
        @glass_xmin = [@glass_xmin || xs.min, xs.min].min
      end
    end
    diag
  end

  def visible_path?(*ents)
    ents.all? do |e|
      (!e.respond_to?(:hidden?) || !e.hidden?) && (!e.respond_to?(:layer) || e.layer.nil? || !e.layer.respond_to?(:visible?) || e.layer.visible?)
    end
  end

  # 接している区間をつなぐ
  def merge_intervals(ivs)
    out = []
    ivs.sort.each do |a, b|
      if out.any? && a <= out[-1][1] + 5
        out[-1][1] = [out[-1][1], b].max
      else
        out << [a, b]
      end
    end
    out
  end

  def sign_mat(key)
    name, rgb = SIGN_MATS[key]
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  def step_i_sign
    model.start_operation('サイン（Takatsuki Common Ground・高槻市章）', true)
    log = []
    find_named(SIGN_GROUP).each { |g, _| g.erase! if g.valid? }
    bld = model.entities.find { |e| container?(e) && e.name.start_with?(BUILDING_PREFIX) }
    host = bld ? bld.definition.entities : model.entities
    sg = host.add_group
    sg.name = SIGN_GROUP
    sg.transformation = bld.transformation.inverse if bld

    # 文字（3D テキスト）
    tg = sg.entities.add_group
    tg.name = "文字 #{SIGN_TEXT}"
    tg.entities.add_3d_text(SIGN_TEXT, TextAlignLeft, SIGN_FONT, SIGN_BOLD, false, SIGN_TEXT_H.mm, 0.0, 0.0, true, SIGN_DEPTH.mm)
    len = tg.bounds.width.to_mm
    tg.transformation = west_gable_axes(SIGN_TEXT_NORTH_Y, SIGN_TEXT_BASE_Z)
    tg.material = sign_mat(:text)
    log << "文字「#{SIGN_TEXT}」（#{SIGN_FONT}#{SIGN_BOLD ? ' Bold' : ''}、高さ #{SIGN_TEXT_H.round}、長さ 約#{len.round}）: Y #{SIGN_TEXT_NORTH_Y.round}〜#{(SIGN_TEXT_NORTH_Y - len).round}、下端 Z #{SIGN_TEXT_BASE_Z.round}"

    # 高槻市章（トレースした輪郭を面にして厚さを付ける）
    lg = sg.entities.add_group
    lg.name = '高槻市章'
    sc = SIGN_LOGO_H / LOGO_PX_H
    to_pts = ->(poly) { poly.map { |x, y| pt(x * sc, y * sc, 0) } }
    face = lg.entities.add_face(to_pts.call(LOGO_OUTER))
    LOGO_HOLES.each do |h|
      hf = lg.entities.add_face(to_pts.call(h))
      hf.erase! if hf && hf.valid?
    end
    face.reverse! if face.normal.z < 0
    face.pushpull(SIGN_DEPTH.mm)
    w = LOGO_PX_W * sc
    lg.transformation = west_gable_axes(SIGN_LOGO_CY + w / 2, SIGN_LOGO_BASE_Z)
    lg.material = sign_mat(:logo)
    log << "高槻市章（幅 #{w.round}×高さ #{SIGN_LOGO_H.round}）: 中心 Y #{SIGN_LOGO_CY.round}、下端 Z #{SIGN_LOGO_BASE_Z.round}"

    # --- I2. 西の妻面のガラス部に木の縦格子 ---
    find_named(GLASS_LATTICE_GROUP).each { |g, _| g.erase! if g.valid? }
    polys = []
    @glass_xmin = nil
    diag = gable_glass_faces(model.entities, Geom::Transformation.new, nil, polys)
    # 格子はガラスの外面（西側）に、すき間 10 で付ける
    lat_x = @glass_xmin ? [@glass_xmin - LAT_GAP - LAT_D, @glass_xmin - LAT_GAP] : nil
    if polys.empty?
      log << '（スキップ）西の妻面（棟より南）にガラスの面が見つかりません。範囲内の面（材料別）:'
      diag.each { |k, v| log << "    #{k}: #{v.size}面 例 Y#{v.first[0].map(&:round)} Z#{v.first[1].map(&:round)} X#{v.first[2].round}" }
    else
      wood = mat_prefix('05_木格子') || mat_prefix('05_')
      # 既存の木格子（同じ面にある縦の部材）と重ならないようにする。非表示（タグを隠している等）の格子は数えない
      existing = []
      find_named('妻面 木格子・欄間').each do |lg_, ltr|
        next unless visible_path?(lg_)
        lg_.definition.entities.each do |e|
          next unless container?(e) && visible_path?(e)
          mn, mx = world_bb_mm(e, ltr)
          existing << [mn, mx] if mn && mn[0] < lat_x[1] + 50 && mx[0] > lat_x[0] - 50
        end
      end
      lg = host.add_group
      lg.name = GLASS_LATTICE_GROUP
      lg.transformation = bld.transformation.inverse if bld
      q = GLASS_SEARCH
      ys = polys.flatten(1).map(&:first).map { |y| y.clamp(q[:y0], q[:y1]) }
      k = ((ys.min - LAT_Y0) / LAT_PITCH).floor
      n_lat = 0
      n_skip = 0
      loop do
        ya = LAT_Y0 + k * LAT_PITCH
        yb = ya + LAT_W
        break if ya > ys.max
        k += 1
        next if ya < q[:y0] || yb > q[:y1]
        ivs = polys.flat_map { |pl| intersect_intervals(intersect_intervals(y_intervals(pl, ya + 1), y_intervals(pl, yb - 1)), [[q[:z0] + 100, 1e9]]) }
        merge_intervals(ivs).each do |z0, z1|
          next if z1 - z0 < 200
          if existing.any? { |mn, mx| mn[1] < yb - 5 && mx[1] > ya + 5 && [mx[2], z1].min - [mn[2], z0].max > 100 }
            n_skip += 1
            next
          end
          box(lg.entities, lat_x[0], ya, z0, lat_x[1], yb, z1, wood)
          n_lat += 1
        end
      end
      log << "西の妻面のガラス部（#{polys.size}面、X #{@glass_xmin.round}）の外面に木の縦格子 #{n_lat}本（#{LAT_W.round}×#{LAT_D.round} @#{LAT_PITCH.round}、#{wood.name}）" \
             "#{n_skip.positive? ? "。既存の格子と重なる #{n_skip}か所は省略" : ''}"
    end

    model.commit_operation
    puts "[STEP I 完了]\n  " + log.join("\n  ")
    log
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP I でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
  end

  # ===========================================================================
  # STEP J: 外構を 261006 の CAD どおりに作り直す（木は対象外）
  #   ・CAD（複合施設プラン 261006）の柱位置がモデルの通り芯と一致（CAD 座標 −(46,975, 105,961) = モデル座標）
  #   ・CAD の線で囲まれた地面の領域（園路・広場、ひろばの芝生、植栽帯、駐車場、クスノキのにわ 等）を面にし、
  #     ベンチ・花壇・あそびの丘・ステップ・屋根付きデッキ・門柱・駐車場の区画線を立体で作る
  #   ・旧外構（260909）の要素は CAD に無いもの（市道・木製塀・あそび場 等）も含めてすべて削除
  #   ・1回だけ実行（作り直す場合は EXT_FORCE = true）
  # ===========================================================================
  EXT_GROUP_NAMES = ['外構 (ランドスケープ検討_260909)', '外構 (261006 CAD)'].freeze
  EXT_NEW_NAME = '外構 (261006 CAD)'.freeze
  EXT_FORCE = false
  EXT_GL = -150.0            # 外構の地盤面（1FL −150）
  EXT_BENCH_H = 420.0
  EXT_PLANTER_H = 450.0
  EXT_STOOL_H = 400.0
  EXT_STEP_RISE = 300.0      # ステップ（休憩所）1段の高さ（5段、ひろば側が低い）
  EXT_MOUND_RISE = 450.0     # あそびの丘 1段の高さ（4段）
  EXT_KIDNEY_DECK_H = 300.0  # 屋根付きデッキの床の高さ（地盤から）
  EXT_KIDNEY_ROOF_Z = 2_600.0 # 屋根付きデッキの屋根の下端（地盤から）
  EXT_GATE_H = 2_400.0
  # 用途 → 材料（既存の外構の材料を使う。無い場合は作る）
  EXT_MATS = {
    'paving'      => ['62_外構_園路・広場舗装', [205, 198, 182]],
    'paving_ring' => ['62_外構_園路・広場舗装', [205, 198, 182]],
    'hiroba_lawn' => ['64_外構_芝生(ひろば)', [150, 190, 110]],
    'lawn'        => ['52_外構_芝生', [160, 200, 120]],
    'planting'    => ['65_外構_植栽地(地被・低木)', [100, 140, 80]],
    'asphalt'     => ['53_外構_アスファルト', [80, 80, 80]],
    'kusunoki'    => ['69_外構_クスノキのにわ(土系舗装)', [200, 170, 120]],
    'steps'       => ['62_外構_園路・広場舗装', [205, 198, 182]],
    'bench'       => ['70_外構_ベンチ(白)', [235, 235, 230]],
    'deck'        => ['36_ウッドデッキ', [170, 120, 80]],
    'engawa'      => ['27_床_御影石', [160, 160, 160]],
    'line'        => ['67_外構_区画線', [245, 245, 245]],
    'gate'        => ['66_外構_門柱(石)', [150, 145, 135]],
    'planter'     => ['TF_外構_植栽桝_コンクリート #B4B0A8', [180, 176, 168]]
  }.freeze

  # ---- 外構（261006 CAD を変換したデータ。座標はモデル原点 mm）----
  EXT_REGIONS = [
    ['paving',
     [[40687, -55463], [41270, -46203], [41298, -44987], [41228, -43787], [41065, -42608], [40811, -41454],
      [40468, -40330], [40041, -39240], [39531, -38190], [38942, -37184], [38277, -36227], [37539, -35323],
      [36731, -34477], [35855, -33693], [34915, -32977], [33914, -32332], [32854, -31765], [31816, -31312],
      [29806, -30569], [27618, -29868], [25407, -29265], [23178, -28761], [20933, -28354], [18676, -28046],
      [16409, -27837], [14137, -27725], [11862, -27713], [9587, -27799], [7316, -27984], [5052, -28267],
      [2799, -28650], [559, -29132], [-1664, -29712], [-3867, -30392], [-5489, 65335], [33112, 68090],
      [33133, 58353], [48922, 58483], [48690, 49647], [48095, 49435], [47416, 49135], [46766, 48787], [46147, 48396],
      [45562, 47963], [45012, 47489], [44498, 46979], [44024, 46433], [43589, 45855], [43198, 45246], [42851, 44608],
      [42549, 43945], [42296, 43258], [42093, 42550], [41622, 40063], [41341, 37906], [41172, 35738], [41116, 33562],
      [41116, 5322], [41139, 4500], [41208, 3685], [41323, 2879], [41482, 2083], [41684, 1300], [41930, 532],
      [42217, -221], [42545, -956], [42914, -1672], [43322, -2367], [43769, -3039], [44253, -3686], [44775, -4307],
      [45332, -4901], [45925, -5464], [46552, -5996], [47209, -6492], [47889, -6948], [48589, -7362], [49310, -7735],
      [50047, -8066], [50801, -8355], [51568, -8601], [52347, -8805], [53136, -8964], [53933, -9080], [54737, -9151],
      [55545, -9178], [56356, -9159], [57168, -9095], [57978, -8984], [60659, -8457], [62541, -8184], [64426, -8008],
      [66312, -7928], [68195, -7943], [70071, -8053], [71937, -8256], [73790, -8553], [75625, -8942], [77440, -9423],
      [79230, -9995], [80993, -10658], [82724, -11411], [84420, -12253], [86077, -13184], [87692, -14203],
      [89337, -15379], [90896, -16655], [92366, -18028], [93742, -19492], [95021, -21041], [96197, -22673],
      [97267, -24381], [98231, -26169], [97778, -26238], [96964, -26448], [96183, -26734], [95440, -27092],
      [94739, -27517], [94297, -27848], [93900, -26434], [93391, -25075], [92772, -23768], [92046, -22520],
      [91219, -21337], [90293, -20226], [89274, -19193], [88165, -18245], [87177, -17499], [86169, -16793],
      [85142, -16126], [84095, -15499], [83031, -14911], [81950, -14364], [80854, -13856], [79744, -13388],
      [78621, -12961], [77485, -12574], [76339, -12227], [75183, -11921], [74018, -11655], [72846, -11431],
      [71667, -11247], [70482, -11104], [69294, -11002], [68102, -10942], [66909, -10922], [65714, -10945],
      [64520, -11009], [63327, -11114], [62137, -11261], [60950, -11451], [59767, -11682], [58591, -11955],
      [57421, -12271], [56260, -12629], [55107, -13029], [53965, -13473], [52834, -13958], [52077, -14314],
      [51144, -14784], [50249, -15310], [49394, -15889], [48580, -16520], [47811, -17199], [47088, -17924],
      [46412, -18693], [45787, -19503], [45214, -20352], [44694, -21237], [44231, -22155], [43826, -23106],
      [43481, -24085], [43198, -25090], [42979, -26120], [42827, -27161], [42744, -28203], [42729, -29241],
      [42780, -30273], [42896, -31295], [43076, -32305], [43320, -33300], [43626, -34276], [43993, -35232],
      [44420, -36162], [44907, -37066], [45451, -37939], [46052, -38779], [46709, -39583], [47422, -40347],
      [48433, -41301], [49952, -42436], [51810, -43666], [53731, -44787], [55711, -45796], [57745, -46691],
      [59828, -47470], [61956, -48130], [64123, -48669], [66111, -49062], [68111, -49372], [70120, -49601],
      [72137, -49748], [74157, -49812], [76179, -49794], [78201, -49694], [80219, -49511], [81264, -49362],
      [82291, -49151], [83298, -48879], [84282, -48548], [85241, -48160], [86173, -47717], [87075, -47219],
      [87945, -46668], [88781, -46066], [89579, -45415], [90339, -44716], [91056, -43971], [91730, -43182],
      [92358, -42349], [92937, -41475], [93466, -40560], [94084, -41125], [94739, -41614], [95440, -42040],
      [96183, -42398], [96964, -42683], [97778, -42893], [98622, -43022], [99491, -43066], [100360, -43022],
      [101204, -42893], [101470, -42824], [101615, -43671], [101855, -44504], [102182, -45302], [102594, -46056],
      [103086, -46761], [103653, -47409], [104292, -47995], [104998, -48511], [106158, -49230], [107345, -49900],
      [108558, -50520], [109794, -51089], [111053, -51607], [112333, -52073], [113631, -52487], [114950, -52847],
      [115635, -59920], [114381, -58532], [112978, -57187], [111494, -55953], [109936, -54834], [108311, -53832],
      [106626, -52949], [104887, -52186], [103101, -51547], [101275, -51033], [99415, -50647], [97530, -50390],
      [95625, -50266], [93707, -50275], [91782, -50421], [89859, -50704], [87943, -51129], [86438, -51496],
      [84926, -51818], [83406, -52095], [81881, -52327], [80350, -52514], [78816, -52656], [77279, -52753],
      [75740, -52806], [74201, -52813], [72661, -52775], [71123, -52692], [69586, -52564], [68053, -52390],
      [66524, -52172], [65000, -51908], [63482, -51600], [61630, -51151], [59804, -50619], [58005, -50006],
      [56236, -49314], [54500, -48542], [52800, -47692], [51138, -46766], [49163, -45565], [48791, -45416],
      [48406, -45316], [48013, -45266], [47616, -45267], [47222, -45318], [46834, -45421], [46458, -45574],
      [46105, -45775], [45785, -46017], [45501, -46296], [45255, -46607], [45051, -46947], [44892, -47312],
      [44779, -47697], [44717, -48098], [44036, -55767]],
     [[[38112, 47799], [38596, 47853], [38112, 47853], [38112, 56853], [25450, 56853], [25450, 41050], [38112, 41050]], [[4896, -6250], [4873, -7450], [4929, -8612], [5061, -9761], [5269, -10893], [5549, -12003], [5901, -13090], [6323, -14149], [6812, -15177], [7368, -16172], [7987, -17128], [8670, -18044], [9414, -18915], [10216, -19739], [11076, -20512], [11992, -21231], [12962, -21892], [13974, -22486], [15015, -23007], [16082, -23454], [17170, -23827], [18276, -24126], [19395, -24352], [20525, -24503], [21661, -24580], [22800, -24583], [23938, -24511], [25070, -24365], [26194, -24143], [27306, -23847], [28401, -23476], [29476, -23029], [30527, -22508], [31541, -21916], [32505, -21264], [33417, -20553], [34276, -19787], [35078, -18970], [35823, -18104], [36509, -17193], [37133, -16241], [37693, -15249], [38187, -14222], [38615, -13163], [38972, -12075], [39258, -10960], [39471, -9824], [39608, -8668], [39668, -7496], [39647, -6528], [39550, -5569], [39379, -4624], [39134, -3697], [38818, -2792], [38431, -1912], [37974, -1064], [37450, -250], [37450, -6250]], [[37250, -50], [37250, 40850], [25250, 40850], [25250, 56750], [-50, 56750], [-50, 30250], [4950, 30250], [4950, -50]]]],
    ['hiroba_lawn',
     [[94297, -27848], [94084, -28007], [93481, -28555], [92932, -29159], [92443, -29813], [92017, -30514],
      [91659, -31257], [91373, -32038], [91164, -32853], [91035, -33697], [90991, -34566], [91035, -35435],
      [91164, -36279], [91373, -37093], [91659, -37874], [92017, -38617], [92443, -39318], [92932, -39972],
      [93466, -40560], [92937, -41475], [92358, -42349], [91730, -43182], [91056, -43971], [90339, -44716],
      [89579, -45415], [88781, -46066], [87945, -46668], [87075, -47219], [86173, -47717], [85241, -48160],
      [84282, -48548], [83298, -48879], [82291, -49151], [81264, -49362], [80219, -49511], [78201, -49694],
      [76179, -49794], [74157, -49812], [72137, -49748], [70120, -49601], [68111, -49372], [66111, -49062],
      [64123, -48669], [61956, -48130], [59828, -47470], [57745, -46691], [55711, -45796], [53731, -44787],
      [51810, -43666], [49952, -42436], [48433, -41301], [47422, -40347], [46709, -39583], [46052, -38779],
      [45451, -37939], [44880, -37017], [48346, -35023], [47794, -33942], [47356, -32821], [47031, -31667],
      [46823, -30489], [46731, -29297], [46758, -28098], [46903, -26902], [47168, -25718], [47550, -24567],
      [48041, -23467], [48635, -22426], [49327, -21451], [50112, -20548], [50984, -19725], [51937, -18989],
      [52966, -18347], [51022, -14855], [51995, -14355], [52834, -13958], [53965, -13473], [55107, -13029],
      [56260, -12629], [57421, -12271], [58591, -11955], [59767, -11682], [60950, -11451], [62137, -11261],
      [63327, -11114], [64520, -11009], [65714, -10945], [66909, -10922], [68102, -10942], [69294, -11002],
      [70482, -11104], [71667, -11247], [72846, -11431], [74018, -11655], [75183, -11921], [76339, -12227],
      [77485, -12574], [78621, -12961], [79744, -13388], [80854, -13856], [81950, -14364], [83031, -14911],
      [84095, -15499], [85142, -16126], [86169, -16793], [87177, -17499], [88165, -18245], [89274, -19193],
      [90293, -20226], [91219, -21337], [92046, -22520], [92772, -23768], [93391, -25075], [93900, -26434]],
     []],
    ['lawn',
     [[112997, -25451], [113044, -32751], [107793, -32751], [107609, -32038], [107323, -31257], [106965, -30514],
      [106540, -29813], [106050, -29159], [105502, -28555], [104898, -28007], [104244, -27517], [103543, -27092],
      [102800, -26734], [102019, -26448], [101204, -26238], [100360, -26109], [99491, -26066], [98622, -26109],
      [98231, -26169], [97267, -24381], [96197, -22673], [95021, -21041], [93742, -19492], [92366, -18028],
      [90896, -16655], [89337, -15379], [87692, -14203], [86077, -13184], [84420, -12253], [82724, -11411],
      [80993, -10658], [79230, -9995], [77440, -9423], [75625, -8942], [73790, -8553], [71937, -8256],
      [70071, -8053], [68195, -7943], [66312, -7928], [64426, -8008], [62541, -8184], [60659, -8457], [57978, -8984],
      [57168, -9095], [56356, -9159], [55545, -9178], [54737, -9151], [53933, -9080], [53136, -8964], [52347, -8805],
      [51568, -8601], [50801, -8355], [50047, -8066], [49310, -7735], [48589, -7362], [47889, -6948], [47209, -6492],
      [46552, -5996], [45925, -5464], [45332, -4901], [44775, -4307], [44253, -3686], [43769, -3039], [43322, -2367],
      [42914, -1672], [42545, -956], [42217, -221], [41930, 532], [41684, 1300], [41482, 2083], [41323, 2879],
      [41208, 3685], [41139, 4500], [41116, 5322], [41116, 33562], [41172, 35738], [41341, 37906], [41622, 40063],
      [42093, 42550], [42296, 43258], [42549, 43945], [42851, 44608], [43198, 45246], [43589, 45855], [44024, 46433],
      [44498, 46979], [45012, 47489], [45562, 47963], [46147, 48396], [46766, 48787], [47416, 49135], [48095, 49435],
      [48690, 49647], [48456, 40705], [51711, 40528], [48537, 1256], [87006, -2370], [110343, -1730],
      [109227, -24943]],
     []],
    ['lawn',
     [[39668, -7496], [39608, -8668], [39471, -9824], [39258, -10960], [38972, -12075], [38615, -13163],
      [38187, -14222], [37693, -15249], [37133, -16241], [36509, -17193], [35823, -18104], [35078, -18970],
      [34276, -19787], [33417, -20553], [32505, -21264], [31541, -21916], [30527, -22508], [29476, -23029],
      [28401, -23476], [27306, -23847], [26194, -24143], [25070, -24365], [23938, -24511], [22800, -24583],
      [21661, -24580], [20525, -24503], [19395, -24352], [18276, -24126], [17170, -23827], [16082, -23454],
      [15015, -23007], [13974, -22486], [12962, -21892], [11992, -21231], [11076, -20512], [10216, -19739],
      [9414, -18915], [8670, -18044], [7987, -17128], [7368, -16172], [6812, -15177], [6323, -14149], [5901, -13090],
      [5549, -12003], [5269, -10893], [5061, -9761], [4929, -8612], [4873, -7450], [4896, -6250], [37450, -6250],
      [37450, -250], [37974, -1064], [38431, -1912], [38818, -2792], [39134, -3697], [39379, -4624], [39550, -5569],
      [39647, -6528]],
     []],
    ['planting',
     [[44501, -50566], [44717, -48098], [44779, -47697], [44892, -47312], [45051, -46947], [45255, -46607],
      [45501, -46296], [45785, -46017], [46105, -45775], [46458, -45574], [46834, -45421], [47222, -45318],
      [47616, -45267], [48013, -45266], [48406, -45316], [48791, -45416], [49163, -45565], [51138, -46766],
      [52800, -47692], [54500, -48542], [56236, -49314], [58005, -50006], [59804, -50619], [61630, -51151],
      [63482, -51600], [65000, -51908], [66524, -52172], [68053, -52390], [69586, -52564], [71123, -52692],
      [72661, -52775], [74201, -52813], [75740, -52806], [77279, -52753], [78816, -52656], [80350, -52514],
      [81881, -52327], [83406, -52095], [84926, -51818], [86438, -51496], [87943, -51129], [89859, -50704],
      [91782, -50421], [93707, -50275], [95625, -50266], [97530, -50390], [99415, -50647], [101275, -51033],
      [103101, -51547], [104887, -52186], [106626, -52949], [108311, -53832], [109936, -54834], [111494, -55953],
      [112978, -57187], [114381, -58532], [115635, -59920], [116089, -64601], [109465, -65323], [109619, -61771],
      [48301, -52473]],
     []],
    ['planting',
     [[31756, -34935], [-3828, -32649], [-3867, -30392], [-1664, -29712], [559, -29132], [2799, -28650],
      [5052, -28267], [7316, -27984], [9587, -27799], [11862, -27713], [14137, -27725], [16409, -27837],
      [18676, -28046], [20933, -28354], [23178, -28761], [25407, -29265], [27618, -29868], [29806, -30569],
      [31816, -31312], [32854, -31765], [33914, -32332], [34915, -32977], [35855, -33693], [36731, -34477],
      [37539, -35323], [38277, -36227], [38942, -37184], [39531, -38190], [40041, -39240], [40468, -40330],
      [40811, -41454], [41065, -42608], [41228, -43787], [41298, -44987], [41270, -46203], [41055, -49599],
      [30842, -48077]],
     []],
    ['asphalt',
     [[25450, 56853], [38112, 56853], [38112, 41050], [25450, 41050]],
     []],
    ['paving_ring',
     [[107991, -34566], [107947, -35435], [107819, -36279], [107609, -37093], [107323, -37874], [106965, -38617],
      [106540, -39318], [106050, -39972], [105502, -40576], [104898, -41125], [104244, -41614], [103543, -42040],
      [102800, -42398], [102019, -42683], [101204, -42893], [100360, -43022], [99491, -43066], [98622, -43022],
      [97778, -42893], [96964, -42683], [96183, -42398], [95440, -42040], [94739, -41614], [94084, -41125],
      [93481, -40576], [92932, -39972], [92443, -39318], [92017, -38617], [91659, -37874], [91373, -37093],
      [91164, -36279], [91035, -35435], [90991, -34566], [91035, -33697], [91164, -32853], [91373, -32038],
      [91659, -31257], [92017, -30514], [92443, -29813], [92932, -29159], [93481, -28555], [94084, -28007],
      [94739, -27517], [95440, -27092], [96183, -26734], [96964, -26448], [97778, -26238], [98622, -26109],
      [99491, -26066], [100360, -26109], [101204, -26238], [102019, -26448], [102800, -26734], [103543, -27092],
      [104244, -27517], [104898, -28007], [105502, -28555], [106050, -29159], [106540, -29813], [106965, -30514],
      [107323, -31257], [107609, -32038], [107819, -32853], [107947, -33697]],
     [[[105991, -34566], [105963, -34003], [105879, -33457], [105744, -32930], [105559, -32425], [105327, -31944], [105052, -31490], [104735, -31067], [104380, -30677], [103990, -30322], [103566, -30005], [103113, -29729], [102632, -29498], [102127, -29313], [101600, -29177], [101054, -29094], [100491, -29066], [99929, -29094], [99383, -29177], [98856, -29313], [98350, -29498], [97870, -29729], [97416, -30005], [96993, -30322], [96602, -30677], [96247, -31067], [95931, -31490], [95655, -31944], [95423, -32425], [95238, -32930], [95103, -33457], [95020, -34003], [94991, -34566], [95020, -35128], [95103, -35674], [95238, -36201], [95423, -36706], [95655, -37187], [95931, -37641], [96247, -38064], [96602, -38455], [96993, -38810], [97416, -39126], [97870, -39402], [98350, -39633], [98856, -39818], [99383, -39954], [99929, -40037], [100491, -40066], [101054, -40037], [101600, -39954], [102127, -39818], [102632, -39633], [103113, -39402], [103566, -39126], [103990, -38810], [104380, -38455], [104735, -38064], [105052, -37641], [105327, -37187], [105559, -36706], [105744, -36201], [105879, -35674], [105963, -35128]]]],
    ['planting',
     [[114653, -49792], [114950, -52847], [113631, -52487], [112333, -52073], [111053, -51607], [109794, -51089],
      [108558, -50520], [107345, -49900], [106158, -49230], [104998, -48511], [104292, -47995], [103653, -47409],
      [103086, -46761], [102594, -46056], [102182, -45302], [101855, -44504], [101615, -43671], [101470, -42824],
      [102019, -42683], [102800, -42398], [103543, -42040], [104244, -41614], [104898, -41125], [105502, -40576],
      [106050, -39972], [106540, -39318], [106965, -38617], [107348, -37806], [113077, -37806], [113155, -49805]],
     []],
    ['kusunoki',
     [[105991, -34566], [105963, -35128], [105879, -35674], [105744, -36201], [105559, -36706], [105327, -37187],
      [105052, -37641], [104735, -38064], [104380, -38455], [103990, -38810], [103566, -39126], [103113, -39402],
      [102632, -39633], [102127, -39818], [101600, -39954], [101054, -40037], [100491, -40066], [99929, -40037],
      [99383, -39954], [98856, -39818], [98350, -39633], [97870, -39402], [97416, -39126], [96993, -38810],
      [96602, -38455], [96247, -38064], [95931, -37641], [95655, -37187], [95423, -36706], [95238, -36201],
      [95103, -35674], [95020, -35128], [94991, -34566], [95020, -34003], [95103, -33457], [95238, -32930],
      [95423, -32425], [95655, -31944], [95931, -31490], [96247, -31067], [96602, -30677], [96993, -30322],
      [97416, -30005], [97870, -29729], [98350, -29498], [98856, -29313], [99383, -29177], [99929, -29094],
      [100491, -29066], [101054, -29094], [101600, -29177], [102127, -29313], [102632, -29498], [103113, -29729],
      [103566, -30005], [103990, -30322], [104380, -30677], [104735, -31067], [105052, -31490], [105327, -31944],
      [105559, -32425], [105744, -32930], [105879, -33457], [105963, -34003]],
     []],
    ['steps',
     [[44880, -37017], [44420, -36162], [43993, -35232], [43626, -34276], [43320, -33300], [43076, -32305],
      [42896, -31295], [42780, -30273], [42729, -29241], [42744, -28203], [42827, -27161], [42979, -26120],
      [43198, -25090], [43481, -24085], [43826, -23106], [44231, -22155], [44694, -21237], [45214, -20352],
      [45787, -19503], [46412, -18693], [47088, -17924], [47811, -17199], [48580, -16520], [49394, -15889],
      [50249, -15310], [51022, -14855], [52966, -18347], [51937, -18989], [50984, -19725], [50112, -20548],
      [49327, -21451], [48635, -22426], [48041, -23467], [47550, -24567], [47168, -25718], [46903, -26902],
      [46758, -28098], [46731, -29297], [46823, -30489], [47031, -31667], [47356, -32821], [47794, -33942],
      [48346, -35023]],
     []],
    ['paving',
     [[113044, -32751], [113077, -37806], [107348, -37806], [107609, -37093], [107819, -36279], [107947, -35435],
      [107991, -34566], [107947, -33697], [107793, -32751]],
     []]
  ].freeze
  EXT_DECK = [
    [[25250, 56750], [-50, 56750], [-50, 30250], [4950, 30250], [4950, -50], [37250, -50], [37250, 798],
     [37450, -153], [37450, -6250], [-3250, -6250], [-3250, -3250], [4850, -3250], [4850, 30150], [-3250, 30150],
     [-3250, 59950], [25450, 59950], [25450, 56950], [25471, 56854], [25449, 56853], [25449, 41050], [28792, 41049],
     [28834, 40850], [25250, 40850]]
  ].freeze
  EXT_ENGAWA = [
    [[4850, -3250], [-3250, -3250], [-3250, 30150], [4850, 30150]]
  ].freeze
  EXT_BENCHES = [
    [[6378, -14261], [6830, -14060], [7197, -14833], [7598, -15579], [8032, -16297], [8497, -16988], [8991, -17650],
     [9515, -18283], [10065, -18886], [10642, -19459], [11243, -20002], [11867, -20513], [12513, -20992],
     [13180, -21439], [13866, -21854], [14570, -22235], [15290, -22582], [16026, -22895], [16775, -23173],
     [17537, -23415], [18311, -23621], [19094, -23791], [19886, -23924], [20685, -24019], [21489, -24077],
     [22299, -24095], [23111, -24074], [23926, -24014], [24741, -23913], [25555, -23772], [26367, -23589],
     [27176, -23365], [27980, -23098], [28778, -22788], [28970, -23250], [27635, -23744], [26733, -24009],
     [25823, -24225], [24905, -24391], [23982, -24507], [23056, -24573], [22129, -24591], [21203, -24558],
     [20281, -24477], [19363, -24346], [18452, -24167], [17550, -23939], [16660, -23662], [15782, -23336],
     [14920, -22962], [14075, -22540], [13253, -22072], [12463, -21563], [11704, -21015], [10979, -20429],
     [10287, -19807], [9632, -19150], [9013, -18460], [8432, -17738], [7890, -16987], [7389, -16207], [6929, -15400]],
    [[72476, -6040], [71289, -5722], [70086, -5500], [68872, -5374], [67655, -5344], [66439, -5410], [65229, -5572],
     [64033, -5830], [62804, -6195], [62753, -6191], [62704, -6175], [62660, -6146], [62625, -6107], [62602, -6060],
     [62591, -6009], [62595, -5957], [62611, -5907], [62640, -5864], [62679, -5829], [62726, -5806], [63934, -5443],
     [65161, -5178], [66401, -5012], [67649, -4944], [68898, -4975], [70143, -5104], [71377, -5332], [72595, -5658],
     [72665, -5697], [72713, -5756], [72735, -5830], [72727, -5909], [72689, -5979], [72629, -6026], [72555, -6049]],
    [[81243, -8159], [81322, -8164], [81391, -8198], [81442, -8255], [81468, -8330], [81463, -8410], [81429, -8478],
     [81372, -8529], [81297, -8556], [80527, -8626], [79759, -8630], [78996, -8567], [78242, -8439], [77503, -8247],
     [76782, -7990], [76083, -7672], [75410, -7291], [75352, -7237], [75321, -7167], [75319, -7090], [75346, -7016],
     [75401, -6958], [75471, -6927], [75548, -6924], [75622, -6952], [76264, -7315], [76932, -7620], [77620, -7864],
     [78326, -8048], [79046, -8170], [79774, -8230], [80508, -8227]],
    [[59324, -44520], [60415, -44921], [61516, -45287], [62626, -45618], [63746, -45912], [64872, -46171],
     [66006, -46394], [67145, -46581], [68289, -46731], [69438, -46846], [70590, -46924], [71744, -46966],
     [72900, -46971], [74057, -46940], [75214, -46871], [76369, -46767], [77523, -46625], [77606, -47219],
     [76433, -47363], [75258, -47470], [74083, -47539], [72907, -47571], [71732, -47566], [70559, -47523],
     [69388, -47444], [68221, -47327], [67057, -47174], [65899, -46984], [64747, -46758], [63602, -46495],
     [62465, -46195], [61336, -45860], [60217, -45488], [59108, -45080]]
  ].freeze
  EXT_LBENCHES = [
    [[1693, 65576], [1693, 61576], [-1307, 61576], [-1307, 62076], [1193, 62076], [1193, 65576]],
    [[9193, 61576], [6193, 61576], [6193, 65576], [6693, 65576], [6693, 62076], [9193, 62076]],
    [[17693, 65576], [17693, 61576], [14693, 61576], [14693, 62076], [17193, 62076], [17193, 65576]],
    [[25193, 61576], [22193, 61576], [22193, 65576], [22693, 65576], [22693, 62076], [25193, 62076]]
  ].freeze
  EXT_PLANTERS = [
    [[25193, 65576], [25193, 62076], [22693, 62076], [22693, 65576]],
    [[17193, 65576], [17193, 62076], [14693, 62076], [14693, 65576]],
    [[9193, 65576], [9193, 62076], [6693, 62076], [6693, 65576]],
    [[1193, 65576], [1193, 62076], [-1307, 62076], [-1307, 65576]],
    [[-4750, 48950], [-3250, 48950], [-3250, 43950], [-4750, 43950]],
    [[-4750, 40950], [-3250, 40950], [-3250, 35950], [-4750, 35950]],
    [[-4750, 56950], [-3250, 56950], [-3250, 51950], [-4750, 51950]]
  ].freeze
  EXT_MOUND = [
    [[85256, -11373], [84885, -10956], [84586, -10497], [84361, -10003], [84212, -9484], [84141, -8948],
     [84150, -8406], [84240, -7865], [84414, -7335], [84666, -6837], [84984, -6391], [85362, -6001], [85790, -5672],
     [86262, -5410], [86771, -5220], [87307, -5106], [87864, -5073], [88580, -5103], [89292, -5165], [90000, -5260],
     [90703, -5387], [91399, -5547], [92087, -5739], [92767, -5963], [93436, -6218], [94338, -6620], [95206, -7074],
     [96038, -7580], [96833, -8134], [97590, -8735], [98305, -9380], [98978, -10067], [99606, -10793],
     [100188, -11557], [100722, -12357], [101206, -13189], [101639, -14053], [102018, -14945], [102342, -15863],
     [102609, -16806], [102817, -17771], [102874, -18336], [102844, -18893], [102730, -19433], [102535, -19947],
     [102266, -20425], [101925, -20858], [101516, -21239], [101045, -21556], [100530, -21797], [99994, -21951],
     [99447, -22020], [98898, -22005], [98358, -21907], [97836, -21727], [97343, -21467], [96888, -21126]],
    [[97169, -19960], [85942, -10645], [85661, -10326], [85438, -9970], [85274, -9585], [85172, -9180],
     [85135, -8761], [85165, -8337], [85265, -7916], [85431, -7515], [85656, -7154], [85931, -6837], [86251, -6568],
     [86609, -6353], [86999, -6195], [87413, -6101], [87846, -6073], [88814, -6123], [89769, -6236], [90708, -6410],
     [91628, -6645], [92528, -6939], [93404, -7290], [94254, -7696], [95074, -8156], [95863, -8668], [96618, -9231],
     [97337, -9843], [98015, -10503], [98652, -11208], [99243, -11958], [99788, -12750], [100282, -13584],
     [100801, -14626], [101233, -15705], [101578, -16815], [101833, -17951], [101875, -18397], [101842, -18834],
     [101738, -19254], [101567, -19649], [101333, -20010], [101041, -20330], [100695, -20600], [100301, -20811],
     [99875, -20953], [99442, -21019], [99009, -21011], [98586, -20933], [98181, -20786], [97804, -20574],
     [97464, -20297]],
    [[87991, -10500], [87420, -10356], [87123, -10256], [86857, -10108], [86626, -9916], [86434, -9687],
     [86286, -9428], [86186, -9145], [86138, -8844], [86148, -8531], [86215, -8225], [86335, -7945], [86501, -7695],
     [86709, -7480], [86950, -7305], [87222, -7176], [87516, -7097], [87828, -7073], [88668, -7114], [89499, -7207],
     [90317, -7350], [91121, -7542], [91909, -7782], [92679, -8069], [93429, -8402], [94157, -8779], [94860, -9200],
     [95537, -9664], [96186, -10168], [96804, -10713], [97390, -11296], [97941, -11918], [98456, -12576],
     [98932, -13269], [99275, -13832], [99588, -14410], [99873, -15001], [100129, -15606], [100354, -16222],
     [100550, -16849], [100715, -17485], [100849, -18130], [100875, -18437], [100844, -18736], [100759, -19019],
     [100625, -19280], [100445, -19512], [100225, -19709], [99968, -19865], [99679, -19971], [99374, -20021],
     [99074, -20012], [98785, -19950], [98515, -19836], [98269, -19675], [98056, -19470], [97881, -19226],
     [97753, -18946]],
    [[91359, -10752], [90464, -10324], [89546, -9952], [88606, -9638], [87647, -9382], [87423, -9283],
     [87254, -9115], [87155, -8899], [87140, -8654], [87215, -8420], [87364, -8235], [87568, -8114], [87810, -8073],
     [88797, -8129], [89772, -8263], [90730, -8473], [91667, -8756], [92579, -9112], [93462, -9539], [94311, -10036],
     [95122, -10601], [96018, -11348], [96835, -12169], [97569, -13058], [98217, -14010], [98775, -15017],
     [99238, -16074], [99603, -17174], [99865, -18310], [99863, -18538], [99781, -18743], [99630, -18905],
     [99424, -19004], [99196, -19020], [98985, -18953], [98812, -18815], [98697, -18617]]
  ].freeze
  EXT_STEPS = [
    [[44420, -36162], [43993, -35232], [43626, -34276], [43320, -33300], [43076, -32305], [42896, -31295],
     [42780, -30273], [42729, -29241], [42744, -28203], [42827, -27161], [42979, -26120], [43198, -25090],
     [43481, -24085], [43826, -23106], [44231, -22155], [44694, -21237], [45214, -20352], [45787, -19503],
     [46412, -18693], [47088, -17924], [47811, -17199], [48580, -16520], [49394, -15889], [50249, -15310],
     [51022, -14855], [52966, -18347], [52377, -18698], [51881, -19029], [51169, -19571], [50718, -19960],
     [50112, -20548], [49677, -21027], [49299, -21488], [48775, -22213], [48456, -22717], [48041, -23467],
     [47769, -24039], [47550, -24567], [47340, -25152], [47091, -26011], [46903, -26902], [46818, -27476],
     [46742, -28367], [46731, -29297], [46760, -29857], [46818, -30450], [46960, -31333], [47167, -32204],
     [47356, -32821], [47541, -33336], [47894, -34158], [48346, -35023], [44880, -37017]],
    [[44420, -36162], [43993, -35232], [43626, -34276], [43320, -33300], [43076, -32305], [42896, -31295],
     [42780, -30273], [42729, -29241], [42744, -28203], [42827, -27161], [42979, -26120], [43198, -25090],
     [43481, -24085], [43826, -23106], [44231, -22155], [44694, -21237], [45214, -20352], [45787, -19503],
     [46412, -18693], [47088, -17924], [47811, -17199], [48580, -16520], [49394, -15889], [50249, -15310],
     [51022, -14855], [52578, -17649], [51949, -18022], [51420, -18375], [50662, -18953], [50180, -19368],
     [49720, -19806], [49282, -20266], [48668, -20996], [48289, -21506], [47769, -22305], [47456, -22858],
     [47170, -23426], [46913, -24007], [46684, -24600], [46485, -25204], [46242, -26126], [46118, -26749],
     [46024, -27378], [45962, -28010], [45927, -28963], [45943, -29598], [45989, -30232], [46118, -31177],
     [46242, -31800], [46396, -32417], [46684, -33326], [46913, -33919], [47170, -34500], [47456, -35068],
     [47653, -35422], [44880, -37017]],
    [[44420, -36162], [43993, -35232], [43626, -34276], [43320, -33300], [43076, -32305], [42896, -31295],
     [42780, -30273], [42729, -29241], [42744, -28203], [42827, -27161], [42979, -26120], [43198, -25090],
     [43481, -24085], [43826, -23106], [44231, -22155], [44694, -21237], [45214, -20352], [45787, -19503],
     [46412, -18693], [47088, -17924], [47811, -17199], [48580, -16520], [49394, -15889], [50249, -15310],
     [51022, -14855], [52189, -16950], [51521, -17346], [50960, -17721], [50418, -18123], [49896, -18551],
     [49396, -19005], [48919, -19482], [48465, -19982], [47833, -20772], [47260, -21607], [46913, -22186],
     [46595, -22781], [46307, -23391], [46048, -24014], [45821, -24650], [45625, -25296], [45391, -26281],
     [45276, -26945], [45193, -27615], [45131, -28626], [45131, -29300], [45164, -29975], [45230, -30646],
     [45329, -31314], [45461, -31976], [45625, -32630], [45931, -33595], [46174, -34225], [46447, -34842],
     [46751, -35445], [46960, -35821], [44880, -37017]],
    [[44420, -36162], [43993, -35232], [43626, -34276], [43320, -33300], [43076, -32305], [42896, -31295],
     [42780, -30273], [42729, -29241], [42744, -28203], [42827, -27161], [42979, -26120], [43198, -25090],
     [43481, -24085], [43826, -23106], [44231, -22155], [44694, -21237], [45214, -20352], [45787, -19503],
     [46412, -18693], [47088, -17924], [47811, -17199], [48580, -16520], [49394, -15889], [50249, -15310],
     [51022, -14855], [51799, -16251], [51397, -16483], [50793, -16865], [50210, -17276], [49647, -17716],
     [49106, -18182], [48589, -18675], [48096, -19192], [47630, -19733], [47190, -20296], [46779, -20879],
     [46397, -21483], [46045, -22104], [45724, -22742], [45435, -23395], [45178, -24061], [44954, -24739],
     [44763, -25428], [44607, -26124], [44484, -26828], [44397, -27537], [44345, -28249], [44327, -28963],
     [44345, -29677], [44436, -30744], [44541, -31450], [44681, -32151], [44854, -32844], [45061, -33527],
     [45302, -34199], [45575, -34859], [45881, -35505], [46267, -36220], [44880, -37017]],
    [[44420, -36162], [43993, -35232], [43626, -34276], [43320, -33300], [43076, -32305], [42896, -31295],
     [42780, -30273], [42729, -29241], [42744, -28203], [42827, -27161], [42979, -26120], [43198, -25090],
     [43481, -24085], [43826, -23106], [44231, -22155], [44694, -21237], [45214, -20352], [45787, -19503],
     [46412, -18693], [47088, -17924], [47811, -17199], [48580, -16520], [49394, -15889], [50249, -15310],
     [51022, -14855], [51410, -15553], [50665, -15994], [50038, -16413], [49139, -17097], [48569, -17589],
     [48023, -18109], [47503, -18655], [46776, -19519], [46327, -20124], [45908, -20751], [45521, -21397],
     [45001, -22400], [44556, -23439], [44188, -24507], [43987, -25233], [43822, -25968], [43693, -26711],
     [43601, -27458], [43532, -28586], [43532, -29340], [43569, -30092], [43642, -30842], [43753, -31587],
     [43900, -32326], [44083, -33057], [44302, -33778], [44556, -34487], [44844, -35183], [45166, -35865],
     [45573, -36619], [44880, -37017]]
  ].freeze
  EXT_KIDNEY = [
    [[-335, -11701], [-201, -11433], [7, -11230], [271, -11106], [568, -11075], [859, -11145], [1104, -11303],
     [1284, -11532], [1381, -11815], [1552, -12708], [1776, -13588], [2050, -14451], [2373, -15296], [2746, -16121],
     [3168, -16923], [3636, -17700], [4315, -18711], [4439, -18989], [4523, -19278], [4567, -19575], [4570, -19874],
     [4532, -20173], [4452, -20467], [4331, -20750], [4171, -21014], [3979, -21249], [3758, -21454], [3513, -21626],
     [3246, -21764], [2962, -21864], [2664, -21924], [2356, -21943], [2049, -21918], [1752, -21852], [1470, -21747],
     [1206, -21605], [964, -21428], [747, -21219], [559, -20980], [405, -20713], [-59, -19644], [-417, -18543],
     [-671, -17418], [-818, -16277], [-859, -15127], [-792, -13976], [-618, -12832]],
    [[4057, -17429], [4756, -18476], [4908, -18816], [5012, -19171], [5066, -19535], [5069, -19904], [5022, -20270],
     [4925, -20630], [4776, -20978], [4580, -21302], [4344, -21591], [4073, -21843], [3771, -22054], [3444, -22223],
     [3095, -22346], [2730, -22420], [2352, -22443], [1974, -22413], [1610, -22332], [1264, -22202], [940, -22028],
     [642, -21811], [376, -21554], [146, -21261], [-44, -20933], [-526, -19821], [-899, -18675], [-1163, -17505],
     [-1316, -16318], [-1358, -15122], [-1289, -13924], [-1108, -12733], [-814, -11557], [-726, -11336],
     [-605, -11138], [-454, -10964], [-278, -10819], [-80, -10705], [135, -10624], [364, -10581], [601, -10576],
     [837, -10612], [1057, -10686], [1260, -10794], [1441, -10933], [1596, -11100], [1723, -11292], [1817, -11505],
     [1875, -11735], [2041, -12600], [2256, -13451], [2521, -14286], [2835, -15104], [3196, -15902], [3603, -16678]]
  ].freeze
  EXT_PARKING = [
    [[38112, 47853], [33112, 47853], [33112, 50853], [38112, 50853]],
    [[38112, 50853], [33112, 50853], [33112, 53853], [38112, 53853]],
    [[38112, 53853], [33112, 53853], [33112, 56853], [38112, 56853]]
  ].freeze
  EXT_GATEPOSTS = [
    [[111235, -34114], [111535, -34114], [111535, -34414], [111235, -34414]],
    [[111248, -36114], [111548, -36114], [111548, -36414], [111248, -36414]]
  ].freeze
  EXT_STOOLS = [[86634, -8360], [87127, -8440], [87615, -8550], [88095, -8688], [86136, -8309], [85637, -8287], [85137, -8295], [88575, -8826], [89056, -8965], [84637, -8303], [84137, -8311], [83637, -8319]].freeze
  EXT_KIDNEY_POSTS = [[-211, -12081], [1964, -14842], [4080, -20439], [1228, -21205]].freeze

  def ext_mat(key)
    name, rgb = EXT_MATS[key]
    prefix = name[/\A\d+_/] || name
    m = model.materials[name] || (name =~ /\A\d+_/ ? mat_prefix(prefix) : nil)
    unless m
      m = model.materials.add(name)
      m.color = Sketchup::Color.new(*rgb)
    end
    m
  end

  # 2mm 未満で続く点は除く（面が作れなくなるのを防ぐ）
  def ext_pts(poly, z)
    out = []
    poly.each do |x, y|
      next if out.any? && Math.hypot(x - out[-1][0], y - out[-1][1]) < 2
      out << [x, y]
    end
    out.pop if out.size > 3 && Math.hypot(out[0][0] - out[-1][0], out[0][1] - out[-1][1]) < 2
    out.map { |x, y| pt(x, y, z) }
  end

  # 1つの要素で面が作れなかった場合も止めずに続け、ログに残す
  def ext_try(log, label)
    yield
  rescue ArgumentError, TypeError => e
    log << "（作れなかった要素）#{label}: #{e.message}"
    nil
  end

  # 穴あきの平らな面
  def ext_face(ents, ext, holes, z, material)
    f = ents.add_face(ext_pts(ext, z))
    return nil unless f
    holes.each do |h|
      hf = ents.add_face(ext_pts(h, z))
      hf.erase! if hf && hf.valid?
    end
    f.reverse! if f.normal.z < 0
    f.material = material
    f.back_material = material
    f
  end

  # 平面形を高さ h だけ押し出す（上面の材料を top で変えられる）
  def ext_solid(ents, poly, z0, h, material, top = nil)
    faces = prism(ents, ext_pts(poly, z0), Geom::Vector3d.new(0, 0, h.mm), material)
    if top
      faces.compact.each do |f|
        next unless f.normal.z > 0.5
        f.material = top
        f.back_material = top
      end
    end
    faces
  end

  def step_j_exterior
    if model.get_attribute(MARK_DICT, 'exterior_261006_done') && !EXT_FORCE
      puts 'STEP J は実行済みのためスキップしました（作り直す場合は EXT_FORCE = true）。'
      return
    end
    model.start_operation('外構（261006 CAD）', true)
    log = []
    g, gtr = EXT_GROUP_NAMES.map { |n| find_named(n).first }.compact.first
    if g
      unique!(g)
      n_old = g.definition.entities.count { |e| container?(e) || e.is_a?(Sketchup::Face) }
      g.definition.entities.clear!
      log << "旧外構の要素 #{n_old}個を削除"
    else
      bld = model.entities.find { |e| container?(e) && e.name.start_with?(BUILDING_PREFIX) }
      host = bld ? bld.definition.entities : model.entities
      g = host.add_group
      gtr = bld ? bld.transformation : Geom::Transformation.new
      lay = model.layers.to_a.find { |l| l.name.start_with?('10_外構') }
      g.layer = lay if lay
    end
    g.name = EXT_NEW_NAME
    ents = g.definition.entities
    sub = lambda do |name|
      s = ents.add_group
      s.name = name
      s.transformation = gtr.inverse
      s.entities
    end
    gl = EXT_GL

    # --- J1. 地面の領域 ---
    names = { 'paving' => '園路・広場', 'paving_ring' => 'クスノキのにわ 外周', 'hiroba_lawn' => 'みんなのひろば（芝生）',
              'lawn' => '芝生', 'planting' => '植栽帯', 'asphalt' => '駐車場（荷物搬入・車いす用）', 'kusunoki' => 'クスノキのにわ',
              'steps' => '休憩所 ステップ' }
    area = Hash.new(0.0)
    EXT_REGIONS.each do |kind, ext, holes|
      ext_try(log, names[kind]) do
        if kind == 'kusunoki'
          ext_solid(sub.call(names[kind]), ext, gl, 150.0, ext_mat(kind))
        elsif kind == 'steps'
          se = sub.call(names[kind])
          EXT_STEPS.each_with_index { |s, i| ext_solid(se, s, gl, EXT_STEP_RISE * (i + 1), ext_mat('steps')) }
        else
          ext_face(sub.call(names[kind]), ext, holes, gl + 10, ext_mat(kind))
        end
      end
      area[names[kind]] += poly_area_m2(ext) - holes.sum { |h| poly_area_m2(h) }
    end
    log << '地面: ' + area.map { |k, v| "#{k} #{v.round}㎡" }.join('、')

    # --- J2. 建物まわりのデッキ（下屋の下と南の 3m）、えんがわひろば ---
    ext_solid(sub.call('つどいのテラス（デッキ）'), EXT_DECK[0], gl, -gl, ext_mat('deck'))
    ext_solid(sub.call('えんがわひろば'), EXT_ENGAWA[0], gl, -gl, ext_mat('engawa'))
    log << "デッキ #{poly_area_m2(EXT_DECK[0]).round}㎡（FL±0）、えんがわひろば #{poly_area_m2(EXT_ENGAWA[0]).round}㎡（御影石）"

    # --- J3. ベンチ・花壇・スツール ---
    be = sub.call('ベンチ')
    (EXT_BENCHES + EXT_LBENCHES).each { |b| ext_try(log, 'ベンチ') { ext_solid(be, b, gl, EXT_BENCH_H, ext_mat('bench')) } }
    pe = sub.call('花壇（植栽桝）')
    EXT_PLANTERS.each { |p| ext_try(log, '花壇') { ext_solid(pe, p, gl, EXT_PLANTER_H, ext_mat('planter'), ext_mat('planting')) } }
    st = sub.call('スツール')
    EXT_STOOLS.each { |x, y| round_prism(st, x, y, gl, EXT_STOOL_H, 150.0, ext_mat('bench')) }
    log << "ベンチ #{EXT_BENCHES.size}基＋花壇まわりのL字ベンチ #{EXT_LBENCHES.size}基（高さ #{EXT_BENCH_H.round}）、" \
           "花壇 #{EXT_PLANTERS.size}基（高さ #{EXT_PLANTER_H.round}）、スツール #{EXT_STOOLS.size}個"

    # --- J4. あそびの丘（等高線ごとに 1段） ---
    mo = sub.call('あそびの丘')
    EXT_MOUND.each_with_index { |m, i| ext_try(log, 'あそびの丘') { ext_solid(mo, m, gl, EXT_MOUND_RISE * (i + 1), ext_mat('lawn')) } }
    log << "あそびの丘 #{EXT_MOUND.size}段（1段 #{EXT_MOUND_RISE.round}、頂部 地盤+#{(EXT_MOUND_RISE * EXT_MOUND.size).round}）"

    # --- J5. 屋根付きデッキ（豆形） ---
    kd = sub.call('屋根付きデッキ')
    deck_poly, roof_poly = EXT_KIDNEY
    ext_solid(kd, deck_poly, gl, EXT_KIDNEY_DECK_H, ext_mat('deck'))
    roof_top = mat_prefix('15_') || ext_mat('lawn')
    roof_bot = mat_prefix('02_') || roof_top
    faces = ext_solid(kd, roof_poly, gl + EXT_KIDNEY_ROOF_Z, 150.0, mat_prefix('14_') || roof_top)
    faces.compact.each do |f|
      m = f.normal.z > 0.5 ? roof_top : (f.normal.z < -0.5 ? roof_bot : nil)
      next unless m
      f.material = m
      f.back_material = m
    end
    steel = mat_prefix('06_')
    EXT_KIDNEY_POSTS.each { |x, y| box(kd, x - 50, y - 50, gl + EXT_KIDNEY_DECK_H, x + 50, y + 50, gl + EXT_KIDNEY_ROOF_Z, steel) }
    log << "屋根付きデッキ: 床 #{poly_area_m2(deck_poly).round}㎡（地盤+#{EXT_KIDNEY_DECK_H.round}）、" \
           "屋根 #{poly_area_m2(roof_poly).round}㎡（下端 地盤+#{EXT_KIDNEY_ROOF_Z.round}）、柱 #{EXT_KIDNEY_POSTS.size}本（□100）"

    # --- J6. 駐車場の区画線・門柱 ---
    pk = sub.call('駐車場 区画線')
    line_m = ext_mat('line')
    EXT_PARKING.each do |r|
      xs = r.map(&:first)
      ys = r.map(&:last)
      x0, x1 = xs.minmax
      y0, y1 = ys.minmax
      [[x0, y0, x1, y0 + 100], [x0, y1 - 100, x1, y1], [x0, y0, x0 + 100, y1]].each do |a, b, c, d|
        f = pk.add_face(pt(a, b, gl + 15), pt(c, b, gl + 15), pt(c, d, gl + 15), pt(a, d, gl + 15))
        next unless f
        f.reverse! if f.normal.z < 0
        f.material = line_m
      end
    end
    gp = sub.call('門柱')
    EXT_GATEPOSTS.each { |p| ext_solid(gp, p, gl, EXT_GATE_H, ext_mat('gate')) }
    log << "駐車場 #{EXT_PARKING.size}台分の区画線、門柱 #{EXT_GATEPOSTS.size}本（高さ #{EXT_GATE_H.round}）"

    model.set_attribute(MARK_DICT, 'exterior_261006_done', true)
    model.commit_operation
    puts "[STEP J 完了]\n  " + log.join("\n  ")
    log
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("STEP J でエラーのため中止しました（モデルは変更されていません）:\n#{e.message}")
    raise
  end

  def poly_area_m2(poly)
    s = 0.0
    poly.each_with_index do |(x0, y0), i|
      x1, y1 = poly[(i + 1) % poly.size]
      s += x0 * y1 - x1 * y0
    end
    (s / 2.0).abs / 1e6
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
    step_e_steel
    step_f_roof
    step_g_roof_steel
    step_h_review
    step_i_sign
    step_j_exterior
    step_b_floor_tags
    UI.messagebox("修正が完了しました。\n詳細は Ruby コンソールのログを確認してください。\n" \
                  "元に戻す場合は [編集]→[元に戻す] を、実行された STEP の数だけ押してください。")
  end
end

puts "TomitaFix #{TomitaFix::VERSION} を読み込みました" if defined?(Sketchup)
TomitaFix.run_all if TomitaFix::AUTO_RUN && defined?(Sketchup)
