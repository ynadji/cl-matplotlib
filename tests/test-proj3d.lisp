;;;; test-proj3d.lisp — Tests for the 3D projection math (proj3d.lisp).
;;;; The pinned numbers were produced once with matplotlib 3.8.4
;;;; (Axes3D.get_proj + proj3d._proj_points); see the "; view" comments.

(in-package #:cl-matplotlib.primitives.tests)

(def-suite proj3d-tests :description "3D projection math")
(in-suite proj3d-tests)

(defun %close (a b &optional (tol 1d-9))
  (<= (abs (- a b)) tol))

(defun %mat-close (m rows &optional (tol 1d-9))
  "M (mat4) matches ROWS, a list of four 4-element lists."
  (loop for row in rows for i from 0
        always (loop for v in row for j from 0
                     always (%close (mat4-ref m i j) v tol))))

(defun %unit-cube-corners ()
  "mplot3d's _unit_cube order for limits (0,1)^3."
  '((0 0 0) (1 0 0) (1 1 0) (0 1 0) (0 0 1) (1 0 1) (1 1 1) (0 1 1)))

(defun %project-corners (m)
  (loop for (x y z) in (%unit-cube-corners)
        collect (multiple-value-list (proj-transform-vec m x y z))))

(defun %corners-close (m expected)
  (loop for got in (%project-corners m)
        for want in expected
        always (every #'%close got want)))

(test mat4-basics
  (let ((i (mat4-identity))
        (a (make-mat4 2 1 0 3  0 1 4 5  5 6 1 1  1 0 2 4)))
    (is (%mat-close (mat4-mul i a) (quote ((2 1 0 3) (0 1 4 5) (5 6 1 1) (1 0 2 4)))))
    ;; A · A⁻¹ = I
    (is (%mat-close (mat4-mul a (mat4-invert a))
                    '((1 0 0 0) (0 1 0 0) (0 0 1 0) (0 0 0 1)) 1d-9))
    (signals error (mat4-invert (make-mat4 1 2 3 4  2 4 6 8  0 0 1 0  0 0 0 1)))))

(test vec3-basics
  (let ((c (vec3-cross (vec3 1 0 0) (vec3 0 1 0))))
    (is (every #'%close (coerce c 'list) '(0 0 1))))
  (is (%close (vec3-norm (vec3-normalize (vec3 3 4 12))) 1.0d0))
  (is (= (norm-angle 190) -170))
  (is (= (norm-angle -190) 170))
  (is (= (norm-angle 180) 180)))

(test default-box-aspect-matches-matplotlib
  ;; (4,4,3) * 1.8294640721620434 / |(4,4,3)|
  (let ((b (default-box-aspect)))
    (is (%close (aref b 0) 1.1428571455583785d0))
    (is (%close (aref b 1) 1.1428571455583785d0))
    (is (%close (aref b 2) 0.8571428591687839d0))))

(test projection-default-view
  ;; view elev=30 azim=-60 roll=0 lims=((0, 1), (0, 1), (0, 1))
  (let ((m (projection-matrix 30 -60 0 0 1 0 1 0 1)))
    (is (%mat-close m '((0.98974332095012563d0 0.57142857277918935d0 0 -0.78058594686465776d0)
                        (-0.28571428638959462d0 0.4948716604750627d0 0.74230749071259428d0 -0.47573243239903162d0)
                        (0 0 0 -10)
                        (-0.49487166047506298d0 0.85714285916878385d0 -0.42857142958439176d0 10.033150115445336d0))))
    (is (%corners-close m
         '((-0.077800684519112304d0 -0.047416058458716236d0 -0.99669594144771101d0)
           (0.021928210113899397d0 -0.079830623773815945d0 -1.0484072201508365d0)
           (0.075089399772856127d0 -0.025643506911161795d0 -0.96196197323900334d0)
           (-0.019205853742688642d0 0.0017574575927980713d0 -0.91824894181548267d0)
           (-0.081272273609853493d0 0.027754997593594823d0 -1.0411700842975196d0)
           (0.022959835426387725d0 -0.0021009707581920007d0 -1.0977301434758719d0)
           (0.078318220491542481d0 0.047731473626010892d0 -1.0033260373969017d0)
           (-0.019992634403927262d0 0.072784074352502892d0 -0.95586562469261205d0))))))

(test projection-with-roll
  ;; view elev=20 azim=45 roll=20 lims=((0, 1), (0, 1), (0, 1))
  (let ((m (projection-matrix 20 45 20 0 1 0 1 0 1)))
    (is (%mat-close m '((-0.6648539947202956d0 0.85391863604356044d0 -0.27548040480249425d0 0.043207881739613693d0)
                        (-0.53611943153458708d0 0.016668598681630127d0 0.75687619169707165d0 -0.11871267942205675d0)
                        (0 0 0 -10)
                        (-0.75938631538192802d0 -0.75938631538192791d0 -0.29316012354348087d0 10.905966377153668d0))))
    (is (%corners-close m
         '((0.0039618572298304169d0 -0.010885113278062334d0 -0.91692928936114004d0)
           (-0.061266565601034002d0 -0.064537224066637949d0 -0.98555374708725796d0)
           (0.024743552688705015d0 -0.067982352289302939d0 -1.0652810914705861d0)
           (0.08841664012125508d0 -0.010056992614180214d0 -0.98555374708725796d0)
           (-0.021886060812979394d0 0.060131457884471329d0 -0.94225784971795501d0)
           (-0.091047222528555738d0 0.010356209456224227d0 -1.0148760595499493d0)
           (-0.0047512339992967978d0 0.013053908127612823d0 -1.0996220615324834d0)
           (0.063089375757637497d0 0.066457343243445516d0 -1.0148760595499493d0))))))

(test projection-nonunit-limits
  ;; view elev=30 azim=-60 roll=0 lims=((-2, 3), (0, 10), (-1, 1)):
  ;; the data box's corners project to the same screen points as the unit cube
  (let ((m (projection-matrix 30 -60 0 -2 3 0 10 -1 1)))
    (is (%mat-close m '((0.19794866419002516d0 0.057142857277918943d0 0 -0.38468861848460745d0)
                        (-0.057142857277918929d0 0.049487166047506276d0 0.37115374535629714d0 -0.21886440159857234d0)
                        (0 0 0 -10)
                        (-0.098974332095012607d0 0.085714285916878394d0 -0.21428571479219588d0 9.6209157364631146d0))))
    (multiple-value-bind (tx ty tz) (proj-transform-vec m -2 0 -1)
      (is (%close tx -0.077800684519112304d0))
      (is (%close ty -0.047416058458716236d0))
      (is (%close tz -0.99669594144771101d0)))
    ;; round trip through the inverse
    (multiple-value-bind (tx ty tz) (proj-transform-vec m 1.5 7 0.25)
      (multiple-value-bind (x y z) (inv-transform (mat4-invert m) tx ty tz)
        (is (%close x 1.5d0 1d-9))
        (is (%close y 7.0d0 1d-9))
        (is (%close z 0.25d0 1d-9))))))

(test proj-transform-vectorized
  (let ((m (projection-matrix 30 -60 0 0 1 0 1 0 1)))
    (multiple-value-bind (xs ys zs) (proj-transform m #(0 1) #(0 0) #(0 0))
      (is (= 2 (length xs)))
      (is (%close (aref xs 0) -0.077800684519112304d0))
      (is (%close (aref ys 1) -0.079830623773815945d0))
      (is (%close (aref zs 1) -1.0484072201508365d0)))))

(test orthographic-projection
  ;; ortho: w is constant, so straight lines stay parallel — the two
  ;; x-edges of the cube's bottom face have equal projected direction
  (let ((m (projection-matrix 30 -60 0 0 1 0 1 0 1 :focal-length nil)))
    (flet ((p (x y z) (multiple-value-list (proj-transform-vec m x y z))))
      (let ((d1 (mapcar #'- (p 1 0 0) (p 0 0 0)))
            (d2 (mapcar #'- (p 1 1 0) (p 0 1 0))))
        (is (every #'%close d1 d2))))))
