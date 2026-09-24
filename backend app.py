import os
import re
from datetime import datetime, timedelta, timezone
from functools import wraps

from flask import Flask, jsonify, request, g
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import jwt

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline


# ============================================================
# FLASK CONFIGURATION
# ============================================================

app = Flask(__name__)
CORS(app)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

app.config["SQLALCHEMY_DATABASE_URI"] = (
    "sqlite:///" + os.path.join(BASE_DIR, "spill.db")
)

app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

app.config["SECRET_KEY"] = os.getenv(
    "SPILL_SECRET",
    "change-this-secret-in-production"
)

db = SQLAlchemy(app)


# ============================================================
# DATABASE MODELS
# ============================================================

class User(db.Model):

    id = db.Column(db.Integer, primary_key=True)

    username = db.Column(
        db.String(80),
        unique=True,
        nullable=False
    )

    email = db.Column(
        db.String(160),
        unique=True,
        nullable=False
    )

    password_hash = db.Column(
        db.String(255),
        nullable=False
    )

    is_admin = db.Column(
        db.Boolean,
        default=False
    )

    created_at = db.Column(
        db.DateTime,
        default=datetime.utcnow
    )


class Post(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    user_id = db.Column(
        db.Integer,
        db.ForeignKey("user.id"),
        nullable=False
    )

    category = db.Column(
        db.String(50),
        nullable=False
    )

    content = db.Column(
        db.Text,
        nullable=False
    )

    status = db.Column(
        db.String(20),
        default="approved"
    )

    risk = db.Column(
        db.String(20),
        default="low"
    )

    created_at = db.Column(
        db.DateTime,
        default=datetime.utcnow
    )

    user = db.relationship(
        "User",
        backref="posts"
    )


class Comment(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    post_id = db.Column(
        db.Integer,
        db.ForeignKey("post.id"),
        nullable=False
    )

    user_id = db.Column(
        db.Integer,
        db.ForeignKey("user.id"),
        nullable=False
    )

    content = db.Column(
        db.Text,
        nullable=False
    )

    created_at = db.Column(
        db.DateTime,
        default=datetime.utcnow
    )

    user = db.relationship("User")

    post = db.relationship(
        "Post",
        backref="comments"
    )


class Reaction(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    post_id = db.Column(
        db.Integer,
        db.ForeignKey("post.id"),
        nullable=False
    )

    user_id = db.Column(
        db.Integer,
        db.ForeignKey("user.id"),
        nullable=False
    )

    kind = db.Column(
        db.String(20),
        default="like"
    )

    __table_args__ = (
        db.UniqueConstraint(
            "post_id",
            "user_id",
            name="unique_reaction"
        ),
    )


class Bookmark(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    post_id = db.Column(
        db.Integer,
        db.ForeignKey("post.id"),
        nullable=False
    )

    user_id = db.Column(
        db.Integer,
        db.ForeignKey("user.id"),
        nullable=False
    )

    __table_args__ = (
        db.UniqueConstraint(
            "post_id",
            "user_id",
            name="unique_bookmark"
        ),
    )


class Report(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    post_id = db.Column(
        db.Integer,
        db.ForeignKey("post.id"),
        nullable=False
    )

    reporter_id = db.Column(
        db.Integer,
        db.ForeignKey("user.id"),
        nullable=False
    )

    reason = db.Column(
        db.String(80),
        nullable=False
    )

    details = db.Column(
        db.Text,
        default=""
    )

    status = db.Column(
        db.String(20),
        default="pending"
    )

    created_at = db.Column(
        db.DateTime,
        default=datetime.utcnow
    )

    post = db.relationship("Post")

    reporter = db.relationship("User")


# ============================================================
# AI / ML MODERATION
# ============================================================

TRAIN_TEXTS = [

    "hello everyone have a great day",

    "does anyone want to join the study group",

    "the canteen food was good today",

    "i am nervous about tomorrow exam",

    "can someone help me with this assignment",

    "this is a funny college story",

    "i like the campus festival",

    "someone should kill you",

    "i will hurt you",

    "go die",

    "i know where you live",

    "send me your private phone number",

    "share her address and phone number",

    "you are disgusting and worthless",

    "explicit sexual content and nude photos"
]


TRAIN_LABELS = [

    "safe",
    "safe",
    "safe",
    "safe",
    "safe",
    "safe",
    "safe",

    "threat",
    "threat",
    "threat",
    "threat",

    "privacy",
    "privacy",

    "abuse",

    "sexual"
]


moderation_model = Pipeline(
    [
        (
            "tfidf",
            TfidfVectorizer(
                ngram_range=(1, 2),
                lowercase=True
            )
        ),

        (
            "clf",
            LogisticRegression(
                max_iter=1000
            )
        )
    ]
)


moderation_model.fit(
    TRAIN_TEXTS,
    TRAIN_LABELS
)


RULES = {

    "threat": [

        r"\bkill\b",
        r"\bhurt you\b",
        r"\bgo die\b",
        r"\battack\b",
        r"\bshoot\b"

    ],

    "privacy": [

        r"\bphone number\b",
        r"\bhome address\b",
        r"\bprivate address\b",
        r"\bpersonal information\b"

    ],

    "sexual": [

        r"\bnude\b",
        r"\bnudes\b",
        r"\bexplicit sexual\b"

    ],

    "abuse": [

        r"\bworthless\b",
        r"\bdisgusting\b",
        r"\bstupid\b"

    ]
}


def moderate_text(text):

    normalized = re.sub(
        r"\s+",
        " ",
        text.lower()
    ).strip()

    for category, patterns in RULES.items():

        for pattern in patterns:

            if re.search(
                pattern,
                normalized
            ):

                return category, "high"

    prediction = moderation_model.predict(
        [normalized]
    )[0]

    probabilities = moderation_model.predict_proba(
        [normalized]
    )[0]

    confidence = float(
        max(probabilities)
    )

    if prediction == "safe":

        return "safe", "low"

    if confidence >= 0.65:

        return prediction, "high"

    return prediction, "medium"


def moderation_action(category, risk):

    if category == "safe":

        return "allow"

    if (
        category in {
            "threat",
            "privacy",
            "sexual"
        }
        and risk == "high"
    ):

        return "block"

    return "warn"


# ============================================================
# AUTHENTICATION
# ============================================================

def make_token(user):

    payload = {

        "user_id": user.id,

        "is_admin": user.is_admin,

        "exp":
            datetime.now(timezone.utc)
            + timedelta(days=7)
    }

    return jwt.encode(
        payload,
        app.config["SECRET_KEY"],
        algorithm="HS256"
    )


def auth_required(function):

    @wraps(function)
    def wrapper(*args, **kwargs):

        header = request.headers.get(
            "Authorization",
            ""
        )

        if not header.startswith(
            "Bearer "
        ):

            return jsonify({
                "error":
                "Authentication required"
            }), 401

        token = header.split(
            " ",
            1
        )[1]

        try:

            payload = jwt.decode(
                token,
                app.config["SECRET_KEY"],
                algorithms=["HS256"]
            )

            user = db.session.get(
                User,
                payload["user_id"]
            )

            if not user:

                raise ValueError(
                    "User does not exist"
                )

            g.user = user

        except Exception:

            return jsonify({
                "error":
                "Invalid or expired token"
            }), 401

        return function(
            *args,
            **kwargs
        )

    return wrapper


def admin_required(function):

    @wraps(function)
    @auth_required
    def wrapper(*args, **kwargs):

        if not g.user.is_admin:

            return jsonify({
                "error":
                "Admin access required"
            }), 403

        return function(
            *args,
            **kwargs
        )

    return wrapper


# ============================================================
# POST JSON
# ============================================================

def post_json(post):

    like_count = Reaction.query.filter_by(
        post_id=post.id
    ).count()

    bookmark = Bookmark.query.filter_by(
        post_id=post.id,
        user_id=g.user.id
    ).first()

    liked = Reaction.query.filter_by(
        post_id=post.id,
        user_id=g.user.id
    ).first()

    return {

        "id": post.id,

        "author": "Anonymous",

        "category": post.category,

        "content": post.content,

        "risk": post.risk,

        "status": post.status,

        "created_at":
            post.created_at.isoformat(),

        "likes": like_count,

        "comments":
            len(post.comments),

        "liked":
            bool(liked),

        "bookmarked":
            bool(bookmark)
    }


# ============================================================
# BASIC ROUTE
# ============================================================

@app.get("/")
def index():

    return jsonify({

        "app": "SPILL",

        "status": "running"

    })


# ============================================================
# REGISTER
# ============================================================

@app.post("/api/register")
def register():

    data = request.get_json(
        silent=True
    ) or {}

    username = str(
        data.get(
            "username",
            ""
        )
    ).strip()

    email = str(
        data.get(
            "email",
            ""
        )
    ).strip().lower()

    password = str(
        data.get(
            "password",
            ""
        )
    )

    if (
        len(username) < 3
        or len(password) < 6
        or "@" not in email
    ):

        return jsonify({
            "error":
            "Username, valid email and password of 6+ characters are required"
        }), 400

    existing = User.query.filter(
        (User.username == username)
        |
        (User.email == email)
    ).first()

    if existing:

        return jsonify({
            "error":
            "Username or email already exists"
        }), 409

    user = User(

        username=username,

        email=email,

        password_hash=
            generate_password_hash(
                password
            )
    )

    db.session.add(user)

    db.session.commit()

    return jsonify({

        "token":
            make_token(user),

        "user": {

            "id": user.id,

            "username":
                user.username,

            "is_admin":
                False
        }

    }), 201


# ============================================================
# LOGIN
# ============================================================

@app.post("/api/login")
def login():

    data = request.get_json(
        silent=True
    ) or {}

    login_value = str(
        data.get(
            "login",
            ""
        )
    ).strip().lower()

    password = str(
        data.get(
            "password",
            ""
        )
    )

    user = User.query.filter(

        (
            db.func.lower(
                User.email
            )
            == login_value
        )

        |

        (
            db.func.lower(
                User.username
            )
            == login_value
        )

    ).first()

    if (
        not user
        or not check_password_hash(
            user.password_hash,
            password
        )
    ):

        return jsonify({
            "error":
            "Invalid login credentials"
        }), 401

    return jsonify({

        "token":
            make_token(user),

        "user": {

            "id":
                user.id,

            "username":
                user.username,

            "is_admin":
                user.is_admin
        }

    })


# ============================================================
# CURRENT USER
# ============================================================

@app.get("/api/me")
@auth_required
def me():

    return jsonify({

        "id":
            g.user.id,

        "username":
            g.user.username,

        "is_admin":
            g.user.is_admin
    })


# ============================================================
# GET POSTS
# ============================================================

@app.get("/api/posts")
@auth_required
def posts():

    category = request.args.get(
        "category"
    )

    query = Post.query.filter_by(
        status="approved"
    )

    if category:

        query = query.filter_by(
            category=category
        )

    rows = query.order_by(
        Post.created_at.desc()
    ).all()

    return jsonify([
        post_json(post)
        for post in rows
    ])


# ============================================================
# CREATE POST
# ============================================================

@app.post("/api/posts")
@auth_required
def create_post():

    data = request.get_json(
        silent=True
    ) or {}

    content = str(
        data.get(
            "content",
            ""
        )
    ).strip()

    category = str(
        data.get(
            "category",
            "Other"
        )
    ).strip()

    if len(content) < 3:

        return jsonify({
            "error":
            "Spill must contain at least 3 characters"
        }), 400

    if len(content) > 1000:

        return jsonify({
            "error":
            "Spill must be 1000 characters or less"
        }), 400

    category_detected, risk = moderate_text(
        content
    )

    action = moderation_action(
        category_detected,
        risk
    )

    if action == "block":

        return jsonify({

            "allowed": False,

            "action": "block",

            "category":
                category_detected,

            "risk":
                risk,

            "message":
                "This spill was blocked because it may contain harmful content."

        }), 422

    status = (
        "pending"
        if action == "warn"
        else "approved"
    )

    post = Post(

        user_id=g.user.id,

        category=category,

        content=content,

        status=status,

        risk=risk
    )

    db.session.add(post)

    db.session.commit()

    return jsonify({

        "allowed":
            True,

        "action":
            action,

        "category":
            category_detected,

        "risk":
            risk,

        "message":

            (
                "Published anonymously."
                if action == "allow"
                else
                "Sent for moderation review."
            ),

        "post":
            post_json(post)

    }), 201


# ============================================================
# LIKE
# ============================================================

@app.post("/api/posts/<int:post_id>/like")
@auth_required
def like_post(post_id):

    post = db.session.get(
        Post,
        post_id
    )

    if not post:

        return jsonify({
            "error":
            "Post not found"
        }), 404

    reaction = Reaction.query.filter_by(

        post_id=post_id,

        user_id=g.user.id

    ).first()

    if reaction:

        db.session.delete(
            reaction
        )

        liked = False

    else:

        db.session.add(
            Reaction(
                post_id=post_id,
                user_id=g.user.id
            )
        )

        liked = True

    db.session.commit()

    return jsonify({

        "liked":
            liked,

        "likes":
            Reaction.query.filter_by(
                post_id=post_id
            ).count()
    })


# ============================================================
# BOOKMARK
# ============================================================

@app.post("/api/posts/<int:post_id>/bookmark")
@auth_required
def bookmark_post(post_id):

    post = db.session.get(
        Post,
        post_id
    )

    if not post:

        return jsonify({
            "error":
            "Post not found"
        }), 404

    bookmark = Bookmark.query.filter_by(

        post_id=post_id,

        user_id=g.user.id

    ).first()

    if bookmark:

        db.session.delete(
            bookmark
        )

        saved = False

    else:

        db.session.add(
            Bookmark(
                post_id=post_id,
                user_id=g.user.id
            )
        )

        saved = True

    db.session.commit()

    return jsonify({

        "bookmarked":
            saved
    })


# ============================================================
# COMMENTS
# ============================================================

@app.get("/api/posts/<int:post_id>/comments")
@auth_required
def get_comments(post_id):

    comments = Comment.query.filter_by(
        post_id=post_id
    ).order_by(
        Comment.created_at.asc()
    ).all()

    return jsonify([

        {

            "id":
                comment.id,

            "author":
                "Anonymous",

            "content":
                comment.content,

            "created_at":
                comment.created_at.isoformat()

        }

        for comment in comments

    ])


@app.post("/api/posts/<int:post_id>/comments")
@auth_required
def add_comment(post_id):

    post = db.session.get(
        Post,
        post_id
    )

    if (
        not post
        or post.status != "approved"
    ):

        return jsonify({
            "error":
            "Post not found"
        }), 404

    data = request.get_json(
        silent=True
    ) or {}

    content = str(
        data.get(
            "content",
            ""
        )
    ).strip()

    if (
        not content
        or len(content) > 500
    ):

        return jsonify({
            "error":
            "Comment must be 1-500 characters"
        }), 400

    category, risk = moderate_text(
        content
    )

    if (
        category in {
            "threat",
            "privacy",
            "sexual"
        }
        and risk == "high"
    ):

        return jsonify({
            "error":
            "Comment blocked by moderation"
        }), 422

    comment = Comment(

        post_id=post_id,

        user_id=g.user.id,

        content=content
    )

    db.session.add(comment)

    db.session.commit()

    return jsonify({

        "message":
            "Comment added",

        "id":
            comment.id

    }), 201


# ============================================================
# REPORT
# ============================================================

@app.post("/api/posts/<int:post_id>/report")
@auth_required
def report_post(post_id):

    post = db.session.get(
        Post,
        post_id
    )

    if not post:

        return jsonify({
            "error":
            "Post not found"
        }), 404

    data = request.get_json(
        silent=True
    ) or {}

    reason = str(
        data.get(
            "reason",
            "Other"
        )
    ).strip()

    details = str(
        data.get(
            "details",
            ""
        )
    ).strip()

    report = Report(

        post_id=post_id,

        reporter_id=g.user.id,

        reason=reason,

        details=details
    )

    db.session.add(report)

    db.session.commit()

    return jsonify({

        "message":
            "Report submitted"

    }), 201


# ============================================================
# BOOKMARKS
# ============================================================

@app.get("/api/bookmarks")
@auth_required
def bookmarks():

    rows = Bookmark.query.filter_by(

        user_id=g.user.id

    ).order_by(
        Bookmark.id.desc()
    ).all()

    result = []

    for bookmark in rows:

        post = db.session.get(
            Post,
            bookmark.post_id
        )

        if (
            post
            and post.status == "approved"
        ):

            result.append(
                post_json(post)
            )

    return jsonify(result)


# ============================================================
# ADMIN STATS
# ============================================================

@app.get("/api/admin/stats")
@admin_required
def admin_stats():

    return jsonify({

        "users":
            User.query.count(),

        "posts":
            Post.query.count(),

        "reports":
            Report.query.filter_by(
                status="pending"
            ).count(),

        "blocked":
            Post.query.filter_by(
                status="blocked"
            ).count()
    })


# ============================================================
# ADMIN REPORTS
# ============================================================

@app.get("/api/admin/reports")
@admin_required
def admin_reports():

    reports = Report.query.filter_by(

        status="pending"

    ).order_by(
        Report.created_at.desc()
    ).all()

    return jsonify([

        {

            "id":
                report.id,

            "post_id":
                report.post_id,

            "reason":
                report.reason,

            "details":
                report.details,

            "status":
                report.status,

            "content":
                (
                    report.post.content
                    if report.post
                    else ""
                )

        }

        for report in reports

    ])


# ============================================================
# ADMIN ACTION
# ============================================================

@app.post(
    "/api/admin/reports/<int:report_id>/action"
)
@admin_required
def admin_report_action(report_id):

    report = db.session.get(
        Report,
        report_id
    )

    if not report:

        return jsonify({
            "error":
            "Report not found"
        }), 404

    data = request.get_json(
        silent=True
    ) or {}

    action = data.get(
        "action"
    )

    if action == "remove":

        report.post.status = "blocked"

    elif action == "approve":

        report.post.status = "approved"

    elif action != "dismiss":

        return jsonify({
            "error":
            "Action must be remove, approve or dismiss"
        }), 400

    report.status = "resolved"

    db.session.commit()

    return jsonify({

        "message":
            "Report resolved"

    })


# ============================================================
# DEMO DATA
# ============================================================

def seed_demo():

    existing_admin = User.query.filter_by(
        email="admin@spill.local"
    ).first()

    if existing_admin:

        return

    admin = User(

        username="admin",

        email="admin@spill.local",

        password_hash=
            generate_password_hash(
                "admin123"
            ),

        is_admin=True
    )

    demo = User(

        username="demo",

        email="demo@spill.local",

        password_hash=
            generate_password_hash(
                "demo123"
            ),

        is_admin=False
    )

    db.session.add_all([
        admin,
        demo
    ])

    db.session.commit()

    examples = [

        (
            "Campus",
            "Anyone else excited for the college fest?"
        ),

        (
            "Academics",
            "Can someone share tips for preparing for tomorrow's exam?"
        ),

        (
            "Funny",
            "The canteen queue deserves its own attendance system 😂"
        ),

        (
            "Confession",
            "I finally spoke to my crush today and survived."
        )

    ]

    for category, content in examples:

        post = Post(

            user_id=demo.id,

            category=category,

            content=content,

            status="approved"
        )

        db.session.add(post)

    db.session.commit()


# ============================================================
# DATABASE INITIALIZATION
# ============================================================

with app.app_context():

    db.create_all()

    seed_demo()


# ============================================================
# START SERVER
# ============================================================

if __name__ == "__main__":

    app.run(

        host="0.0.0.0",

        port=5000,

        debug=True
    )