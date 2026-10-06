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
#  STEP I  サイン（西の妻面に Takatsuki Common Ground と高槻市章）
#  STEP B  階ごとのタグ（レイヤー）を作成し、全要素を 1F/2F/3F/RF/複数階 に振り分け
#          - 既存の「部位別タグ」（01_構造… 等）は親グループ側に残すので、
#            部位別・階別のどちらでも表示/非表示を切り替えられる
#
# 使い方:
#   1. 元の .skp を必ず別名でバックアップしてから開く
#   2. [拡張機能]→[Ruby コンソール] を開き、次の1行を貼り付けて Enter（ダウンロードフォルダの最新のファイルを読み込む）
#        f = Dir.glob('C:/Users/zhang/Downloads/tomita_fix*').max_by { |x| File.mtime(x) }; puts f; load f
#      （このファイルを読み込むと STEP A → C → D → E → F → G → H → I → B の順で自動実行されます。
#        実行済みの STEP A・C は自動でスキップします）
#      個別に実行したい場合は、先頭の AUTO_RUN を false にして読み込み後に
#        TomitaFix.step_a_south_void / step_c_rooms / step_d_ceilings / step_e_steel / step_f_roof /
#        step_g_roof_steel / step_h_review / step_i_sign / step_b_floor_tags
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
  VERSION = '2026-10-06 v10.2（STEP A/C/D/E/F/G/H/I/B）'.freeze
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
  LAT_PITCH = 180.0
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
    step_b_floor_tags
    UI.messagebox("修正が完了しました。\n詳細は Ruby コンソールのログを確認してください。\n" \
                  "元に戻す場合は [編集]→[元に戻す] を、実行された STEP の数だけ押してください。")
  end
end

puts "TomitaFix #{TomitaFix::VERSION} を読み込みました" if defined?(Sketchup)
TomitaFix.run_all if TomitaFix::AUTO_RUN && defined?(Sketchup)
